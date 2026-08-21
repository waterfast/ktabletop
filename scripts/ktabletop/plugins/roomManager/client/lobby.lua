local RoomBase = require("ktabletop.plugins.roomManager.common.room-base")

--- Client-side lobby. Only the local player is tracked here (via
--- playerManager); `playerCount` reflects the server-broadcast total.
---@class ClientLobby: RoomBase
---@field playerCount integer
local ClientLobby = class("ClientLobby", RoomBase)

---@param ctx Context
function ClientLobby:initialize(ctx)
  RoomBase.initialize(self, ctx)
  self.playerCount = 0
end

return ClientLobby