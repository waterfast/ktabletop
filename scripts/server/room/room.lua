-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomBase = require "server.room.roombase"

---@class Room: ServerRoomBase
---@field owner ServerPlayer
local Room = RoomBase:subclass("Room")

local nextRoomId = 1

function Room:initialize()
  RoomBase.initialize(self)
  self.id = nextRoomId
  nextRoomId = nextRoomId + 1
  self.owner = nil
  self.name = ""
  self.capacity = 0

  self:setRequestHandler("Room::AddRobot", self.handleAddRobot)
  self:setRequestHandler("Room::Quit", self.handleQuitRoom)
end

function Room:isFull()
  return #self.players >= self.capacity
end

---@param player ServerPlayer
function Room:setOwner(player)
  self.owner = player
  self:broadcast("Room::Owner", { id = player.id })
end

---@param player ServerPlayer
function Room:addPlayer(player)
  if self:isFull() --[[ or self:isStarted() ]] then
    player:notify("ErrorMsg", "Room is full or already started")
    return
  end

  self:broadcast("Room::AddPlayer", {
    id = player.id,
    username = player.username,
  })

  RoomBase.addPlayer(self, player)
  player:notify("Room::Enter", {
    id = self.id,
    name = self.name,
    capacity = self.capacity,
  })

  for _, p in ipairs(self.players) do
    if p ~= player then
      player:notify("Room::AddPlayer", {
        id = p.id,
        username = p.username,
      })
    end
  end

  -- TODO: observer


  if self.owner == nil then
    self:setOwner(player)
  else
    player:notify("Room::Owner", { id = self.owner.id })
  end
end

function Room:handleAddRobot(player)
  if self.owner ~= player then
    return nil, "you need to be room owner to add robot!"
  end

  if self:isFull() then
    return nil, "room is full!"
  end

  local robot = ktabletop.server.playerManager:createRobot()
  self:addPlayer(robot)
end

---@param player ServerPlayer
function Room:handleQuitRoom(player)
  self:removePlayer(player)

  -- TODO: check if is online
  local lobby = ktabletop.server.roomManager.lobby
  lobby:addPlayer(player)

  -- TODO: isOutdated
end

---@param player ServerPlayer
function Room:removePlayer(player)
  if not RoomBase.removePlayer(self, player) then
    return
  end

  self:broadcast("Room::RemovePlayer", { id = player.id })

  if player == self.owner then
    if #self.players > 0 then
      self:setOwner(self.players[1])
    else
      self.owner = nil
    end
  end
end

return Room
