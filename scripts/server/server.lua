-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local class = ktabletop.class

local PlayerManager = require "server.user.player-manager"
local RoomManager = require "server.room.room-manager"

---@class Server: Object
---@field playerManager PlayerManager
---@field roomManager RoomManager
local Server = class("Server")

function Server:initialize()
  self._notificationHandlers = {}
  self._requestHandlers = {}

  self.playerManager = PlayerManager:new(self)
  self.roomManager = RoomManager:new()
end

---@param cmd string
---@param cb fun(self: Server, player: Player, data: any)
function Server:setCallback(cmd, cb)
  assert(self._notificationHandlers[cmd] == nil)
  self._notificationHandlers[cmd] = cb
end

---@param cmd string
---@param cb fun(self: Server, player: Player, data: any): any, string?
function Server:setRequestHandler(cmd, cb)
  assert(self._requestHandlers[cmd] == nil)
  self._requestHandlers[cmd] = async.async(cb)
end

----------------------------------------------------------
--- Below methods are called from C++ code.
----------------------------------------------------------

---@param connId integer
function Server:processNewConnection(connId)
  local player = self.playerManager:createNewPlayer(connId)
  self.roomManager.lobby:addPlayer(player)
end

---@param connId integer
function Server:processDisconnected(connId)
  local player = self.playerManager:findPlayer(connId)
  if not player then
    return
  end

  ktabletop.log.info(string.format("Player %s disconnected", player.username))
  local room = self.roomManager:findRoomOrLobby(player.roomId)
  if room then room:removePlayer(player) end
  self.playerManager:removePlayer(connId)
end

---@param connId integer
---@param command string
---@param data any
function Server:processNotification(connId, command, data)
  local player = self.playerManager:findPlayer(connId)
  if not player then return end

  local f = self._notificationHandlers[command]
  if f then
    return f(self, player, data)
  end

  local room = self.roomManager:findRoomOrLobby(player.roomId)
  if not room then return end

  f = room._notificationHandlers[command]
  if f then
    return f(room, player, data)
  end
end

local requestDispatcher = async.async(function(server, player, requestId, command, data)
  local fn = server._requestHandlers[command]
  local arg1 = server
  if not fn then
    local room = server.roomManager:findRoomOrLobby(player.roomId)
    if room then
      fn = room._requestHandlers[command]
      arg1 = room
    end
  end

  if not fn then
    -- must reply an error message here. the peer is waiting for reply.
    player:reply(false, requestId, ("no match requestHandler for request '%s'"):format(command))
    return
  end

  local ok, reply, err = async.await(fn(arg1, player, data))

  if not ok then
    player:reply(false, requestId, reply)
  elseif err then
    player:reply(false, requestId, err)
  else
    player:reply(true, requestId, reply)
  end
end)

---@param connId integer
---@param requestId integer
---@param command string
---@param data any
function Server:processRequest(connId, requestId, command, data)
  local player = self.playerManager:findPlayer(connId)
  if not player then return end
  requestDispatcher(self, player, requestId, command, data)
end

return Server
