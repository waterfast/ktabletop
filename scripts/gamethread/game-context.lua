-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local GameContextBase = require "core.game-context"
local ServerUser = require "server.user"
local ServerPlayer = require "gamethread.player"
local tablib = kt.tablib

---@class ServerGameContext: GameContextBase
---@field id integer
---@field rawUsers table[]
---@field logic GameLogic
---@field gameFinished boolean
---@field gameType string
---@field logicClass any
---@field bg Boardgame
---@field secret table<string, any>
local ServerGameContext = GameContextBase:subclass("ServerGameContext")

---@param data table
---@param boardgame Boardgame
function ServerGameContext:initialize(data, boardgame)
  GameContextBase.initialize(self)
  self.id = data.id
  self.rawUsers = data.users or {}
  self.gameFinished = false
  self.secret = {}
  self.secret.rng = kt.rand(math.random(os.time()))

  assert(boardgame and boardgame.logicClass,
    ("boardgame '%s' must define logicClass"):format(boardgame and boardgame.id or "?"))
  self.bg = boardgame
  self.gameType = boardgame.id
  self.logicClass = boardgame.logicClass
end

function ServerGameContext:run()
  self.players = tablib.map(self.rawUsers, function(u)
    local user = ServerUser:new(u.connId)
    user.id = u.id
    user.username = u.username
    user.state = u.state or "online"
    local player = ServerPlayer:new(user)
    player.ctx = self
    return player
  end)
  self.logic = self.logicClass:new(self)
  self.logic:start()
end

---@class GameOverResult
---@field winners integer[]? winning player ids, empty or nil means a draw

---@param result? GameOverResult
function ServerGameContext:gameOver(result)
  if self.gameFinished then return end
  self.gameFinished = true

  kt.c.luaEvent("gameOver", { roomId = self.id })
  self:broadcast("Room::GameOver", result or {})

  kt.gamethread:removeContext(self.id)
  if self.logic and self.logic.root then
    self.logic.root:shutdown()
  end
end

---@param command string
---@param data any
---@param players? ServerPlayer[]
function ServerGameContext:broadcast(command, data, players)
  players = players or self.players
  for _, player in ipairs(players) do
    player:notify(command, data)
  end
end

---@param name string
function ServerGameContext:act(name, ...)
  local move = assert(self.bg.publicActions[name],
    ("unknown public action '%s'"):format(name))
  move(self, ...)
  self:broadcast(self.gameType .. "." .. name, { ... })
end

---@param player ServerPlayer
---@param property string
---@param value any
function ServerGameContext:setPlayerProperty(player, property, value)
  player.G[property] = value
  self:broadcastProperty(player, property)
end

---@param player ServerPlayer
---@param property string
function ServerGameContext:broadcastProperty(player, property)
  self:broadcast("PropertyUpdate", { id = player.id, property = property, value = player.G[property] })
end

---@param players? ServerPlayer[]
function ServerGameContext:arrangeSeats(players)
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
function ServerGameContext:delay(ms)
  return async.await(async.wrap(kt.c.delay)(ms))
end

---@param m? integer
---@param n? integer
---@return any
function ServerGameContext:random(m, n)
  return self.secret.rng:random(m, n)
end

---@param x? integer
---@param y? integer
function ServerGameContext:randomseed(x, y)
  return self.secret.rng:randomseed(x, y)
end

---@generic T
---@param t T[]
function ServerGameContext:shuffleTable(t)
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
function ServerGameContext:tableRandomPick(t, n)
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

return ServerGameContext
