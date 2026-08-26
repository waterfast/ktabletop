-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local Lobby = require("ktabletop.plugins.roomManager.server.lobby")
local Room = require("ktabletop.plugins.roomManager.server.room")

---@class RoomManager: Object
---@field ctx Context
---@field rooms table<integer, Room>
---@field lobby Lobby
local RoomManager = class("RoomManager")

---@param ctx Context
function RoomManager:initialize(ctx)
  self.ctx = ctx
  self.rooms = {}
  self.lobby = Lobby:new(ctx)
end

---@param name string
---@param capacity integer
---@return Room
function RoomManager:createRoom(name, capacity)
  local room = Room:new(self.ctx)
  room.name = name
  room.capacity = capacity
  self.rooms[room.id] = room
  return room
end

return RoomManager
