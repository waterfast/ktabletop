local RoomBase = require("ktabletop.plugins.roomManager.common.room-base")
local Observable = require("ktabletop.core.observable")

--- Client-side lobby. Only the local player is tracked here (via
--- playerManager); `playerCount` reflects the server-broadcast total.
---@class ClientLobby: RoomBase, Observable
---@field playerCount integer
local ClientLobby = class("ClientLobby", RoomBase)
ClientLobby:include(Observable)
ClientLobby:registerProperty("playerCount")

---@param ctx Context
function ClientLobby:initialize(ctx)
  RoomBase.initialize(self, ctx)
  self._stringId = "lobby"
  self.playerCount = 0

  self:createObserveObject()
end

return ClientLobby
