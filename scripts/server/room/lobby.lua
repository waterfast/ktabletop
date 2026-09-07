-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomBase = require "server.room.roombase"

---@class Lobby: ServerRoomBase
local Lobby = RoomBase:subclass("Lobby")

function Lobby:initialize()
  RoomBase.initialize(self)

  self.id = 0

  self:setRequestHandler("Lobby::FetchRooms", self.handleFetchRooms)
  self:setRequestHandler("Lobby::CreateRoom", self.handleCreateRoom)
end

---@param player ServerPlayer
function Lobby:addPlayer(player)
  RoomBase.addPlayer(self, player)
  -- TODO: should write some client-side Lua and GUI code here!
  -- Otherwise the room manager is not possible for testing
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
  -- TODO: ehh!!!!!!!!!!
  return {}, nil
end

function Lobby:handleCreateRoom(player, data)
  local rm = ktabletop.server.roomManager
  local room = rm:createRoom(player, data.name, data.capacity)
  if not room then
    return nil, "createRoom failed!"
  end

  room:addPlayer(player)
  self:removePlayer(player)
end

return Lobby
