local RoomBase = require "core.room-base"
local LObject = require "corelib.lobject"

---@class ClientLobby: RoomBase, LObject
---@field playerCount integer
local ClientLobby = RoomBase:subclass("ClientLobby")
ClientLobby:include(LObject)
ClientLobby:Property("playerCount")

function ClientLobby:initialize()
  RoomBase.initialize(self)

  self.playerCount = 0
end

return ClientLobby
