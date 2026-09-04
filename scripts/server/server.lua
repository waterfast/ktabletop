-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local class = ktabletop.class

local PlayerManager = require "server.user.player-manager"
local RoomManager = require "server.room.room-manager"

--- Server-side entry point. Owns the player and room managers and dispatches
--- socket events coming from C++.
---@class Server: Object
---@field playerManager PlayerManager
---@field roomManager RoomManager
local Server = class("Server")

function Server:initialize()
  self._notificationHandlers = {}
  self._requestHandlers = {}

  self.playerManager = PlayerManager:new(self)
  self.roomManager = RoomManager:new(self)
end

---@param cmd string
---@param cb fun(data: any)
function Server:onNotificationGot(cmd, cb)
  local list = self._notificationHandlers[cmd]
  if not list then
    list = {}
    self._notificationHandlers[cmd] = list
  end
  list[#list + 1] = cb
end

---@param cmd string
---@param cb fun(player: Player, data: any): any, string?
function Server:onRequestGot(cmd, cb)
  assert(self._requestHandlers[cmd] == nil)
  self._requestHandlers[cmd] = async.async(cb)
end

-- Called by C++ when a client connects.
---@param connId integer
function Server:onNewConnection(connId)
  local player = self.playerManager:addConnection(connId)
  self.roomManager.lobby:addPlayer(player)
end

-- Called by C++ when a notification arrives.
---@param connId integer
---@param command string
---@param data any
function Server:processNotification(connId, command, data)
  local list = self._notificationHandlers[command]
  if not list then
    return
  end
  for _, fn in ipairs(list) do
    fn(data)
  end
end

local requestDispatcher = async.async(function(server, connId, requestId, command, data)
  local fn = server._requestHandlers[command]
  if not fn then
    return
  end

  local player = server.playerManager:findPlayer(connId)
  assert(player, ("cannot find player of connId %d in request #%d"):format(connId, requestId))

  local ok, reply, err = async.await(fn(player, data))
  if not ok then
    player:reply(false, requestId, reply)
  elseif err then
    player:reply(false, requestId, err)
  else
    player:reply(true, requestId, reply)
  end
end)

-- Called by C++ when a request arrives.
---@param connId integer
---@param requestId integer
---@param command string
---@param data any
function Server:processRequest(connId, requestId, command, data)
  requestDispatcher(self, connId, requestId, command, data)
end

return Server
