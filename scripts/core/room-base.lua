local class = ktabletop.class
local tablib = ktabletop.tablib
local async = require "corelib.async"

---@class RoomBase: Object
---@field id integer
---@field name string
---@field capacity integer
---@field players Player[]
---@field observers Player[]
local RoomBase = class("RoomBase")

function RoomBase:initialize()
  self.id = 0
  self.players = {}
  self.observers = {}

  self._notificationHandlers = {}
  self._requestHandlers = {}
end

---@param cmd string
function RoomBase:setCallback(cmd, cb)
  assert(self._notificationHandlers[cmd] == nil)
  self._notificationHandlers[cmd] = cb
end

---@param cmd string
function RoomBase:setRequestHandler(cmd, cb)
  assert(self._requestHandlers[cmd] == nil)
  self._requestHandlers[cmd] = async.async(cb)
end


---@param player Player
function RoomBase:addPlayer(player)
  self.players[#self.players + 1] = player
  player.roomId = self.id
end

---@param player Player
---@return boolean removed
function RoomBase:removePlayer(player)
  return tablib.removeOne(self.players, player)
  -- note that player.roomId is not set. Please add they to somewhere.
end

---@param id integer
---@return Player
function RoomBase:findPlayerById(id)
  ---@diagnostic disable-next-line
  return tablib.find(self.players, function(p) return p.id == id end)
end

return RoomBase
