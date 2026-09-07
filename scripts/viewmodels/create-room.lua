local LObject = require "corelib.lobject"
local async = require "corelib.async"

---@class CreateRoomViewModel: Object, LObject
---@field playerCount integer
local CreateRoomViewModel = ktabletop.class("CreateRoomViewModel")
CreateRoomViewModel:include(LObject)

CreateRoomViewModel:Invokable("accepted")

function CreateRoomViewModel:initialize()
end

function CreateRoomViewModel:accepted(data)
  print("create room:", ktabletop.json.encode(data))
  async.async(function()
    return ktabletop.client.myself:request("CreateRoom", data)
  end)()
  -- ktabletop.luaEvent("Client::DisconnectFromHost", nil)
end

return CreateRoomViewModel
