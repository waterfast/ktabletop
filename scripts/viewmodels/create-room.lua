local LObject = require "corelib.lobject"
local async = require "corelib.async"

---@class CreateRoomViewModel: Object, LObject
---@field playerCount integer
local CreateRoomViewModel = ktabletop.class("CreateRoomViewModel")
CreateRoomViewModel:include(LObject)

CreateRoomViewModel:Property("username") -- TODO: when this grow bigger, should bind to player or something
CreateRoomViewModel:Invokable("accepted")

function CreateRoomViewModel:initialize()
  self.username = ktabletop.client.myself.username
end

function CreateRoomViewModel:accepted(data)
  async.async(function()
    return ktabletop.client.myself:request("Lobby::CreateRoom", data)
  end)()
end

return CreateRoomViewModel
