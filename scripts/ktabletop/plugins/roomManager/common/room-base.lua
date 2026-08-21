--- Common room representation shared by client and server.
--- Only holds data both sides need; broadcasting/notifying is server-only
--- and lives in the server subclass.
---@class RoomBase: Object
---@field ctx Context
---@field id integer
---@field players Player[]
---@field observers Player[]
local RoomBase = class("RoomBase")

---@param ctx Context
function RoomBase:initialize(ctx)
  self.ctx = ctx
  self.id = 0
  self.players = {}
  self.observers = {}
end

---@param player Player
function RoomBase:addPlayer(player)
  self.players[#self.players + 1] = player
end

---@param player Player
---@return boolean removed
function RoomBase:removePlayer(player)
  return tablib.removeOne(self.players, player)
end

return RoomBase
