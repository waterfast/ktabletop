local RoomBase = require "core.room-base"
local LObject = require "corelib.lobject"

---@class ClientLobby: RoomBase, LObject
---@field userCount integer
---@field messages { id: integer, username: string, text: string, timestamp: integer }[]
local ClientLobby = RoomBase:subclass("ClientLobby")
ClientLobby:include(LObject)
ClientLobby:Property("userCount")
ClientLobby:Property("rooms")
ClientLobby:Property("messages")

function ClientLobby:initialize()
  RoomBase.initialize(self)

  self.userCount = 0
  self.rooms = {}
  self.messages = {}

  self:setCallback("Room::ChatMessage", self.handleChatMessage)
end

function ClientLobby:handleChatMessage(_, data)
  local msgs = {}
  msgs[1] = data

  for i = 1, #self.messages do
    msgs[i + 1] = self.messages[i]
  end

  self.messages = msgs

  self:notifyPropertyChanged("messages")
end

return ClientLobby
