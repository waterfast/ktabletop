-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local Lobby = require "server.room.lobby"
local Room = require "server.room.room"

local class = ktabletop.class

---@class RoomManager: Object
---@field rooms table<integer, Room>
---@field lobby Lobby
local RoomManager = class("RoomManager")

---@param server Server
function RoomManager:initialize(server)
  self.server = server
  self.rooms = {}
  self.lobby = Lobby:new()

  server:onRequestGot("FetchRoomList", function(player, data)
    return {}, nil
  end)
end

---@param name string
---@param capacity integer
---@return Room
function RoomManager:createRoom(name, capacity)
  local room = Room:new()
  room.name = name
  room.capacity = capacity
  self.rooms[room.id] = room
  return room
end

return RoomManager
