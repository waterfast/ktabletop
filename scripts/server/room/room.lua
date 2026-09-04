-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomBase = require "server.room.roombase"

---@class Room: ServerRoomBase
---@field owner Player?
---@field name string
---@field capacity integer
local Room = RoomBase:subclass("Room")

local nextRoomId = 1

function Room:initialize()
  RoomBase.initialize(self)
  self.id = nextRoomId
  nextRoomId = nextRoomId + 1
  self.owner = nil
  self.name = ""
  self.capacity = 0
end

---@param player Player
function Room:addPlayer(player)
  if #self.players >= self.capacity then
    player:notify("ErrorMsg", "Room is full or already started")
    return
  end

  self:broadcast("AddPlayer", { player.connId })

  player:notify("EnterRoom", { id = self.id, name = self.name, capacity = self.capacity })

  for i = 1, #self.players do
    player:notify("AddPlayer", { self.players[i].connId })
  end

  RoomBase.addPlayer(self, player)

  if self.owner == nil then
    self:setOwner(player)
  else
    player:notify("RoomOwner", { self.owner.connId })
  end
end

---@param player Player
function Room:removePlayer(player)
  if not RoomBase.removePlayer(self, player) then
    return
  end

  self:broadcast("RemovePlayer", { player.connId })

  if player == self.owner then
    if #self.players > 0 then
      self:setOwner(self.players[1])
    else
      self.owner = nil
    end
  end
end

---@param player Player
function Room:setOwner(player)
  self.owner = player
  self:broadcast("RoomOwner", { player.connId })
end

return Room
