-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local class = ktabletop.class

local ClientPlayer = require "client.user.player"
local ClientLobby = require "client.room.lobby"
local ClientRoom = require "client.room.room"

---@class Client: Object
---@field myself ClientPlayer
---@field lobby ClientLobby
---@field room ClientRoom
local Client = class("Client")

function Client:initialize()
  self._notificationHandlers = {}
  self._requestHandlers = {}
  self.pendingUsername = ""

  self.myself = ClientPlayer:new()
  self.lobby = ClientLobby:new()

  self:setCallback("Player::Setup", self.setupPlayer)
  self:setCallback("Lobby::Enter", self.enterLobby)
  self:setCallback("Lobby::UpdateOnlineInfo", self.updateOnlineInfo)

  self:setCallback("Room::Enter", self.enterRoom)
  self:setRequestHandler("Auth::RequestUsername", self.handleAuthRequest)
end

---@param cmd string
---@param cb fun(self: Client, player: Player, data: any)
function Client:setCallback(cmd, cb)
  assert(self._notificationHandlers[cmd] == nil)
  self._notificationHandlers[cmd] = cb
end

---@param cmd string
---@param cb fun(self: Client, player: Player, data: any): any, string?
function Client:setRequestHandler(cmd, cb)
  assert(self._requestHandlers[cmd] == nil)
  self._requestHandlers[cmd] = async.async(cb)
end

-- helper functions that does work from playerManager & roomManager
-- since there's only one special player (myself) and my room

function Client:setupPlayer(_, data)
  self.myself = ClientPlayer:new()
  self.myself.connId = 1001
  self.myself.id = data.id
  self.myself.state = "online"
  self.myself.username = data.username
end

function Client:enterLobby()
  self.myself.roomId = 0
  self.room = nil
  ktabletop.luaEvent("Client::EnterLobby", nil)
end

function Client:updateOnlineInfo(_, data)
  self.lobby.playerCount = data.onlinePlayers
end

function Client:enterRoom(_, data)
  local room = ClientRoom:new()
  room.id = data.id
  room.name = data.name
  room.capacity = data.capacity

  self.room = room

  room:addPlayer(self.myself)

  -- OK let's tell GUI
  ktabletop.luaEvent("Client::EnterRoom", data)
end

function Client:handleAuthRequest(_, _)
  return { username = self.pendingUsername }
end

----------------------------------------------------------
--- Below methods are called from C++ code.
----------------------------------------------------------

---@param host string
---@param port integer
function Client:connectToHost(host, port, username)
  self.pendingUsername = username or ""
  async.async(function()
    local wrapped = async.wrap(ktabletop.connectToHost)
    local ok, ret = async.await(wrapped(host, port))

    if not ok then
      ktabletop.log.warn(("Failed to connect to %s:%d - %s"):format(host, port, tostring(ret)))
      ktabletop.luaEvent("Client::ConnectError", {
        error = tostring(ret or "Unknown error")
      })
    else
      ktabletop.luaEvent("Client::Connected", {})
    end
  end)()
end

-- TODO: use similar logic of server side
-- oh code cloning detected here!

---@param connId integer
---@param command string
---@param data any
function Client:processNotification(connId, command, data)
  local player = self.myself
  if not player then return end

  local f = self._notificationHandlers[command]
  if f then
    return f(self, player, data)
  end

  local room = player.roomId == 0 and self.lobby or self.room
  if not room then return end

  f = room._notificationHandlers[command]
  if f then
    return f(room, player, data)
  end
end

local requestDispatcher = async.async(function(client, connId, requestId, command, data)
  local player = client.myself
  assert(player, ("cannot find player of connId %d in request #%d"):format(connId, requestId))
  player.connId = connId

  local fn = client._requestHandlers[command]
  if not fn then
    return
  end

  local handler = fn(client, player, data)
  player.handlingRequests[requestId] = handler
  local ok, reply = async.await(handler)

  -- canceled by the peer: the registry entry has been removed, do not reply
  if player.handlingRequests[requestId] == nil then
    return
  end
  player.handlingRequests[requestId] = nil

  if not ok then
    player:reply(false, requestId, reply)
  else
    player:reply(true, requestId, reply)
  end
end)

---@param connId integer
---@param requestId integer
---@param command string
---@param data any
function Client:processRequest(connId, requestId, command, data)
  requestDispatcher(self, connId, requestId, command, data)
end

---@param message string
function Client:onSocketError(message)
  -- self.uiHelper:showError(message, "network")
end

return Client
