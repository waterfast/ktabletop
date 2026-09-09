local RoomBase = require "core.room-base"
local LObject = require "corelib.lobject"

---@class ClientLobby: RoomBase, LObject
---@field playerCount integer
local ClientLobby = RoomBase:subclass("ClientLobby")
ClientLobby:include(LObject)
ClientLobby:Property("playerCount")
ClientLobby:Property("rooms")

function ClientLobby:initialize()
  RoomBase.initialize(self)

  self.playerCount = 0
  self.rooms = {}
end

return ClientLobby
