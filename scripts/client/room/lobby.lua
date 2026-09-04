local RoomBase = require "core.room-base"
local Observable = require "corelib.observable"

--- Client-side lobby. Only the local player is tracked here (via
--- playerManager); `playerCount` reflects the server-broadcast total.
---@class ClientLobby: RoomBase, Observable
---@field playerCount integer
local ClientLobby = RoomBase:subclass("ClientLobby")
ClientLobby:include(Observable)
ClientLobby:registerProperty("playerCount")

function ClientLobby:initialize()
  RoomBase.initialize(self)
  self._stringId = "lobby"
  self.playerCount = 0

  self:createObserveObject()
end

return ClientLobby
