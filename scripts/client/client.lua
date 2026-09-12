-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local class = ktabletop.class

local ClientUser = require "client.user"
local ClientLobby = require "client.room.lobby"
local ClientRoom = require "client.room.room"

---@class Client: Object
---@field myself ClientUser
---@field lobby ClientLobby
---@field room ClientRoom
---@field gameContext Object?
local Client = class("Client")

function Client:initialize()
  self._notificationHandlers = {}
  self._requestHandlers = {}
  self.pendingUsername = ""

  self.myself = ClientUser:new()
  self.lobby = ClientLobby:new()

  self:setCallback("User::Setup", self.setupUser)
  self:setCallback("Lobby::Enter", self.enterLobby)
  self:setCallback("Lobby::UpdateOnlineInfo", self.updateOnlineInfo)

  self:setCallback("Room::Enter", self.enterRoom)
  self:setRequestHandler("Auth::RequestUsername", self.handleAuthRequest)
end

---@param cmd string
---@param cb fun(self: Client, user: User, data: any)
function Client:setCallback(cmd, cb)
  assert(self._notificationHandlers[cmd] == nil)
  self._notificationHandlers[cmd] = cb
end

---@param cmd string
---@param cb fun(self: Client, user: User, data: any): any, string?
function Client:setRequestHandler(cmd, cb)
  assert(self._requestHandlers[cmd] == nil)
  self._requestHandlers[cmd] = async.async(cb)
end

-- helper functions that does work from userManager & roomManager
-- since there's only one special user (myself) and my room

function Client:setupUser(_, data)
  self.myself = ClientUser:new()
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
  self.lobby.userCount = data.onlineUsers
end

function Client:enterRoom(_, data)
  local room = ClientRoom:new()
  room.id = data.id
  room.name = data.name
  room.capacity = data.capacity

  self.room = room

  room:addUser(self.myself)

  -- OK let's tell GUI
  ktabletop.luaEvent("Client::EnterRoom", data)
end

---@param gameType string?
---@param data table?
function Client:enterGame(gameType, data)
  gameType = gameType or "chess"
  local bg = ktabletop.boardgames:get(gameType)
  local klass = bg and bg.clientContextClass
  assert(klass, ("no clientContextClass for boardgame '%s'"):format(gameType))
  self.gameContext = klass:new(gameType, data)
  ktabletop.luaEvent("Client::EnterGame", data)
end

function Client:leaveGame()
  self.gameContext = nil
  ktabletop.luaEvent("Client::LeaveGame", nil)
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
  local user = self.myself
  if not user then return end

  local f = self._notificationHandlers[command]
  if f then
    return f(self, user, data)
  end

  local room = user.roomId == 0 and self.lobby or self.room
  if not room then return end

  f = room._notificationHandlers[command]
  if f then
    return f(room, user, data)
  end
end

local requestDispatcher = async.async(function(client, connId, requestId, command, data)
  local user = client.myself
  assert(user, ("cannot find user of connId %d in request #%d"):format(connId, requestId))
  user.connId = connId

  local fn = client._requestHandlers[command]
  if not fn then
    return
  end

  local handler = fn(client, user, data)
  user.handlingRequests[requestId] = handler
  local ok, reply = async.await(handler)

  -- canceled by the peer: the registry entry has been removed, do not reply
  if user.handlingRequests[requestId] == nil then
    return
  end
  user.handlingRequests[requestId] = nil

  if not ok then
    user:reply(false, requestId, reply)
  else
    user:reply(true, requestId, reply)
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
