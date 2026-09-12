-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomBase = require "core.room-base"
local LObject = require "corelib.lobject"
local ClientPlayer = require "client.user.player"

---@class ClientGameRoom: RoomBase, LObject
---@field gameType string
---@field players ClientPlayer[]
---@field observers ClientPlayer[]
---@field messages { id: integer, username: string, text: string, timestamp: integer }[]
---@field page table?
local ClientGameRoom = RoomBase:subclass("ClientGameRoom")
ClientGameRoom:include(LObject)

ClientGameRoom:Property("players")
ClientGameRoom:Property("observers")
ClientGameRoom:Property("messages")

---@param gameType string
---@param data table?
function ClientGameRoom:initialize(gameType, data)
  RoomBase.initialize(self)

  data = data or {}
  self.gameType = gameType
  self.id = data.id or 0
  self.name = data.name or ""
  self.page = data.page

  self.players = {}
  self.observers = {}
  self.messages = {}

  self:setCallback("Room::ChatMessage", self.handleChatMessage)
  self:setCallback("Room::AddPlayer", self.handleAddPlayer)
  self:setCallback("Room::RemovePlayer", self.handleRemovePlayer)
end

---@param player ClientPlayer
function ClientGameRoom:addPlayer(player)
  RoomBase.addPlayer(self, player)
  self:notifyPropertyChanged("players")
end

---@param player ClientPlayer
---@return boolean removed
function ClientGameRoom:removePlayer(player)
  local ret = RoomBase.removePlayer(self, player)
  self:notifyPropertyChanged("players")
  return ret
end

function ClientGameRoom:handleAddPlayer(_, data)
  local p = ClientPlayer:new()
  p.id = data.id
  p.username = data.username
  self:addPlayer(p)
end

function ClientGameRoom:handleRemovePlayer(_, data)
  local p = self:findPlayerById(data.id)
  if p then self:removePlayer(p) end
end

function ClientGameRoom:handleChatMessage(_, data)
  local msgs = { data }
  for i = 1, #self.messages do
    msgs[i + 1] = self.messages[i]
  end

  self.messages = msgs

  self:notifyPropertyChanged("messages")
end

return ClientGameRoom
