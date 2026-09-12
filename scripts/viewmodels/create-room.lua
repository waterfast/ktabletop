local LObject = require "corelib.lobject"
local async = require "corelib.async"

---@class CreateRoomViewModel: Object, LObject
---@field userCount integer
local CreateRoomViewModel = ktabletop.class("CreateRoomViewModel")
CreateRoomViewModel:include(LObject)

CreateRoomViewModel:Property("username") -- TODO: when this grow bigger, should bind to user or something
CreateRoomViewModel:Property("name")
CreateRoomViewModel:Property("capacity")

CreateRoomViewModel:Invokable("updateName")
CreateRoomViewModel:Invokable("updateCapacity")

function CreateRoomViewModel:initialize()
  self.username = ktabletop.client.myself.username
  self.name = ""
  self.capacity = 2
end

function CreateRoomViewModel:updateName(name)
  self.name = name
end

function CreateRoomViewModel:updateCapacity(capacity)
  self.capacity = capacity
end

return CreateRoomViewModel
