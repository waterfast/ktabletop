-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomBase = require "server.room.roombase"

---@class Lobby: ServerRoomBase
local Lobby = RoomBase:subclass("Lobby")

function Lobby:initialize()
  RoomBase.initialize(self)

  self.id = 0

  self:setRequestHandler("Lobby::FetchRooms", self.handleFetchRooms)
  self:setRequestHandler("Room::Create", self.handleCreateRoom)
  self:setRequestHandler("Room::Join", self.handleJoinRoom)
end

---@param player ServerPlayer
function Lobby:addPlayer(player)
  RoomBase.addPlayer(self, player)
  player:notify("Lobby::Enter", nil)
  self:updateOnlineInfo()
end

---@param player ServerPlayer
function Lobby:removePlayer(player)
  RoomBase.removePlayer(self, player)
  self:updateOnlineInfo()
end

function Lobby:updateOnlineInfo()
  self:broadcast("Lobby::UpdateOnlineInfo", {
    onlinePlayers = #self.players,
  })
end

function Lobby:handleFetchRooms()
  local rm = ktabletop.server.roomManager
  local rooms = {}
  for _, room in pairs(rm.rooms) do
    rooms[#rooms + 1] = {
      id = room.id,
      name = room.name,
      capacity = room.capacity,
      playerCount = #room.players,
      ownerId = room.owner and room.owner.id or -1,
    }
  end
  return rooms
end

function Lobby:handleCreateRoom(player, data)
  local rm = ktabletop.server.roomManager
  local room = rm:createRoom(player, data.name, data.capacity)
  if not room then
    return nil, "createRoom failed!"
  end

  return room.id
end

function Lobby:handleJoinRoom(player, data)
  local rm = ktabletop.server.roomManager
  local room = rm:findRoom(data.id)
  if not room then
    return nil, "no such room"
  end

  -- TODO: password check
  -- TODO: isOutdated check

  room:addPlayer(player)
  self:removePlayer(player)
end

return Lobby
