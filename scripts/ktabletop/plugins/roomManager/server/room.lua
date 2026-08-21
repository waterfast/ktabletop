-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomBase = require("ktabletop.plugins.roomManager.server.roombase")
local Commands = require("ktabletop.plugins.playerManager.common.network-commands")

---@class Room: RoomBase
---@field owner Player?
---@field name string
---@field capacity integer
local Room = class("Room", RoomBase)

local nextRoomId = 1

---@param ctx Context
function Room:initialize(ctx)
  RoomBase.initialize(self, ctx)
  self.id = nextRoomId
  nextRoomId = nextRoomId + 1
  self.owner = nil
  self.name = ""
  self.capacity = 0
end

---@param player Player
function Room:addPlayer(player)
  if #self.players >= self.capacity then
    player:notify(Commands.ErrorMsg, "Room is full or already started")
    return
  end

  self:broadcast(Commands.AddPlayer, { player.connId })

  player:notify(Commands.EnterRoom, { id = self.id, name = self.name, capacity = self.capacity })

  for i = 1, #self.players do
    player:notify(Commands.AddPlayer, { self.players[i].connId })
  end

  RoomBase.addPlayer(self, player)

  if self.owner == nil then
    self:setOwner(player)
  else
    player:notify(Commands.RoomOwner, { self.owner.connId })
  end
end

---@param player Player
function Room:removePlayer(player)
  if not RoomBase.removePlayer(self, player) then
    return
  end

  self:broadcast(Commands.RemovePlayer, { player.connId })

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
  self:broadcast(Commands.RoomOwner, { player.connId })
end

return Room
