local RoomBase = require "core.room-base"
local LObject = require "corelib.lobject"
local ClientPlayer = require "client.user.player"

local tablib = ktabletop.tablib

---@class ClientRoom: RoomBase, LObject
---@field players ClientPlayer[]
---@field observers ClientPlayer[]
---@field owner ClientPlayer
---@field findPlayerById fun(self, id): ClientPlayer
local ClientRoom = RoomBase:subclass("ClientRoom")
ClientRoom:include(LObject)

ClientRoom:Property("players")
ClientRoom:Property("owner")

function ClientRoom:initialize()
  RoomBase.initialize(self)

  self:setCallback("Room::Owner", self.setOwner)
  self:setCallback("Room::AddPlayer", self.handleAddPlayer)
  self:setCallback("Room::RemovePlayer", self.handleRemovePlayer)
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

return ClientRoom
