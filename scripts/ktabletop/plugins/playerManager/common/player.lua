--- Common player representation
--- Only holds data both sides need; socket I/O lives in the subclasses.
---@class Player: Object
---@field ctx Context
---@field connId integer
local Player = class("Player")

---@param ctx Context
---@param connId integer
function Player:initialize(ctx, connId)
  self.ctx = ctx
  self.connId = connId
end

return Player