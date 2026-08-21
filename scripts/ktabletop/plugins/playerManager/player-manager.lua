---@class PlayerManager: Object
---@field ctx Context
---@field private players table<integer, Player>
local PlayerManager = class("PlayerManager")

function PlayerManager:initialize(ctx)
  self.ctx = ctx
  self.players = {}
end

---@param player Player
function PlayerManager:addPlayer(player)
  self.players[player.connId] = player
end

---@param connId integer
function PlayerManager:removePlayer(connId)
  self.players[connId] = nil
end

---@param connId integer
---@return Player?
function PlayerManager:findPlayer(connId)
  return self.players[connId]
end

return PlayerManager
