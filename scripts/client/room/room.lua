local RoomBase = require "core.room-base"
local LObject = require "corelib.lobject"
local ClientUser = require "client.user"

local tablib = ktabletop.tablib

---@class ClientRoom: RoomBase, LObject
---@field users ClientUser[]
---@field observers ClientUser[]
---@field owner ClientUser
---@field messages { id: integer, username: string, text: string, timestamp: integer }[]
---@field findUserById fun(self, id): ClientUser
local ClientRoom = RoomBase:subclass("ClientRoom")
ClientRoom:include(LObject)

ClientRoom:Property("users")
ClientRoom:Property("owner")
ClientRoom:Property("messages")

function ClientRoom:initialize()
  RoomBase.initialize(self)

  self.messages = {}

  self:setCallback("Room::Owner", self.setOwner)
  self:setCallback("Room::AddUser", self.handleAddUser)
  self:setCallback("Room::RemoveUser", self.handleRemoveUser)
  self:setCallback("Room::ChatMessage", self.handleChatMessage)
end

---@param user ClientUser
function ClientRoom:addUser(user)
  RoomBase.addUser(self, user)
  self:notifyPropertyChanged("users")
end

---@param user ClientUser
---@return boolean removed
function ClientRoom:removeUser(user)
  local ret = RoomBase.removeUser(self, user)
  self:notifyPropertyChanged("users")
  return ret
end

function ClientRoom:setOwner(_, data)
  self.owner = self:findUserById(data.id)
end

function ClientRoom:handleAddUser(_, data)
  local p = ClientUser:new()
  p.id = data.id
  p.username = data.username

  self:addUser(p)
end

function ClientRoom:handleRemoveUser(_, data)
  local id = data.id

  local p = self:findUserById(id)
  if p then self:removeUser(p) end
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
