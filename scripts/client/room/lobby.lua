local RoomBase = require "core.room-base"
local LObject = require "corelib.lobject"

---@class ClientLobby: RoomBase, LObject
---@field userCount integer
---@field vm LobbyViewModel
local ClientLobby = RoomBase:subclass("ClientLobby")
ClientLobby:include(LObject)
ClientLobby:Property("userCount")
ClientLobby:Property("rooms")

function ClientLobby:initialize()
  RoomBase.initialize(self)

  self.userCount = 0
  self.rooms = {}

  self:setCallback("Room::ChatMessage", self.handleChatMessage)
end

function ClientLobby:setupViewModel()
  ---@diagnostic disable-next-line
  self.vm = ktabletop.viewModelManager:getViewModel({
    type = "lobby",
    params = { self },
  })
end

function ClientLobby:handleChatMessage(_, data)
  self.vm:emitSignal("chatMessage", data)
end

return ClientLobby
