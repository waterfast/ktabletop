-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local ServerUser = require "server.user"
local tablib = ktabletop.tablib

---@class ServerGameContextMixin
---@field id integer
---@field rawUsers table[]
---@field logic GameLogic?
---@field gameFinished boolean
---@field playerClass any
---@field logicClass any
---@field _rng any
local ServerGameContextMixin = {}

---@param data table
function ServerGameContextMixin:initialize(data)
  self.id = data.id
  self.rawUsers = data.users or {}
  self.gameFinished = false
  self._rng = ktabletop.rand(math.random(os.time()))
end

function ServerGameContextMixin:run()
  self.players = tablib.map(self.rawUsers, function(u)
    local user = ServerUser:new(u.connId)
    user.id = u.id
    user.username = u.username
    user.state = u.state or "online"
    local player = self.playerClass:new(user)
    player.ctx = self
    return player
  end)
  self.logic = self.logicClass:new(self)
  self.logic:start()
end

function ServerGameContextMixin:gameOver()
  if self.gameFinished then return end
  self.gameFinished = true

  ktabletop.gamethread:removeContext(self.id)
  if self.logic and self.logic.root then
    self.logic.root:shutdown()
  end
end

---@param command string
---@param data any
---@param players? Player[]
function ServerGameContextMixin:broadcast(command, data, players)
  players = players or self.players
  for _, player in ipairs(players) do
    player:notify(command, data)
  end
end

---@param player Player
---@param property string
---@param value any
function ServerGameContextMixin:setPlayerProperty(player, property, value)
  player[property] = value
  self:broadcastProperty(player, property)
end

---@param player Player
---@param property string
function ServerGameContextMixin:broadcastProperty(player, property)
  self:broadcast("PropertyUpdate", { id = player.id, property = property, value = player[property] })
end

---@param players? Player[]
function ServerGameContextMixin:arrangeSeats(players)
  players = players or self.players
  self.players = players
  for i = 1, #players do
    players[i].seat = i
    players[i].next = players[i + 1] or players[1]
  end
  local ids = tablib.map(players, function(player) return player.id end)
  self:broadcast("ArrangeSeats", { ids = ids })
end

---@param ms integer
function ServerGameContextMixin:delay(ms)
  return async.await(async.wrap(ktabletop.delay)(ms))
end

---@param m? integer
---@param n? integer
---@return any
function ServerGameContextMixin:random(m, n)
  return self._rng:random(m, n)
end

---@param x? integer
---@param y? integer
function ServerGameContextMixin:randomseed(x, y)
  return self._rng:randomseed(x, y)
end

---@generic T
---@param t T[]
function ServerGameContextMixin:shuffleTable(t)
  if #t == 2 then
    if self:random() < 0.5 then
      t[1], t[2] = t[2], t[1]
    end
  else
    for i = #t, 2, -1 do
      local j = self:random(i)
      t[i], t[j] = t[j], t[i]
    end
  end
end

---@generic T
---@param t T[]
---@param n? integer
---@return T|T[]
function ServerGameContextMixin:tableRandomPick(t, n)
  local n0 = n
  n = n or 1
  if #t == 0 then return n0 ~= nil and {} or nil end
  local tmp = { table.unpack(t) }
  local ret = {}
  while n > 0 and #tmp > 0 do
    local i = self:random(1, #tmp)
    ret[#ret + 1] = table.remove(tmp, i)
    n = n - 1
  end
  return n0 == nil and ret[1] or ret
end

return ServerGameContextMixin
