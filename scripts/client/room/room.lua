local RoomBase = require "core.room-base"
local ClientPlayer = require "client.user.player"

local tablib = ktabletop.tablib

---@class ClientRoom: RoomBase
---@field name string?
---@field capacity integer?
---@field ownerConnId integer?
local ClientRoom = RoomBase:subclass("ClientRoom")

---@param id integer
---@param name string
---@param capacity integer
function ClientRoom:initialize(id, name, capacity)
  RoomBase.initialize(self)
  self.id = id
  self.name = name
  self.capacity = capacity
  self.ownerConnId = nil
end

---@param connId integer
---@return ClientPlayer
function ClientRoom:addMember(connId)
  local existing = self:findMember(connId)
  if existing then
    return existing
  end
  local player = ClientPlayer:new(connId)
  self:addPlayer(player)
  return player
end

---@param connId integer
function ClientRoom:removeMember(connId)
  local player = self:findMember(connId)
  if player then
    self:removePlayer(player)
  end
end

---@param connId integer
---@return ClientPlayer?
function ClientRoom:findMember(connId)
  return tablib.find(self.players, function(p) return p.connId == connId end)
end

return ClientRoom
