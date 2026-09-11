local RoomBase = require "core.room-base"
local LObject = require "corelib.lobject"
local ClientPlayer = require "client.user.player"

local tablib = ktabletop.tablib

---@class ClientRoom: RoomBase, LObject
---@field players ClientPlayer[]
---@field observers ClientPlayer[]
---@field owner ClientPlayer
---@field messages { id: integer, username: string, text: string, timestamp: integer }[]
---@field findPlayerById fun(self, id): ClientPlayer
local ClientRoom = RoomBase:subclass("ClientRoom")
ClientRoom:include(LObject)

ClientRoom:Property("players")
ClientRoom:Property("owner")
ClientRoom:Property("messages")

function ClientRoom:initialize()
  RoomBase.initialize(self)

  self.messages = {}

  self:setCallback("Room::Owner", self.setOwner)
  self:setCallback("Room::AddPlayer", self.handleAddPlayer)
  self:setCallback("Room::RemovePlayer", self.handleRemovePlayer)
  self:setCallback("Room::ChatMessage", self.handleChatMessage)
end

---@param player ClientPlayer
function ClientRoom:addPlayer(player)
  RoomBase.addPlayer(self, player)
  self:notifyPropertyChanged("players")
end

---@param player ClientPlayer
---@return boolean removed
function ClientRoom:removePlayer(player)
  local ret = RoomBase.removePlayer(self, player)
  self:notifyPropertyChanged("players")
  return ret
end

function ClientRoom:setOwner(_, data)
  self.owner = self:findPlayerById(data.id)
end

function ClientRoom:handleAddPlayer(_, data)
  local p = ClientPlayer:new()
  p.id = data.id
  p.username = data.username

  self:addPlayer(p)
end

function ClientRoom:handleRemovePlayer(_, data)
  local id = data.id

  local p = self:findPlayerById(id)
  if p then self:removePlayer(p) end
end

function ClientRoom:handleChatMessage(_, data)
  local msgs = {}
  msgs[1] = data

  for i = 1, #self.messages do
    msgs[i + 1] = self.messages[i]
  end

  self.messages = msgs

  self:notifyPropertyChanged("messages")
end

return ClientRoom
