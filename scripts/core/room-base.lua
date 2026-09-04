--- Common room representation shared by client and server.
--- Only holds data both sides need; broadcasting/notifying is server-only
--- and lives in the server subclass.
---@class RoomBase: Object
---@field id integer
---@field players Player[]
---@field observers Player[]
local class = ktabletop.class
local tablib = ktabletop.tablib
local RoomBase = class("RoomBase")

function RoomBase:initialize()
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
