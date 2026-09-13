-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local class = ktabletop.class
local tablib = ktabletop.tablib
local async = require "corelib.async"

---@class GameContextBase: Object
---@field players Player[]
---@field observers Player[]
---@field current Player
---@field capacity integer
---@field timeout integer
---@field mark table<string, any>
local GameContextBase = class("GameContextBase")

function GameContextBase:initialize()
  self.players = {}
  self.observers = {}
  self.current = nil
  self.capacity = 0
  self.timeout = 0
  self.mark = {}

  self._notificationHandlers = {}
  self._requestHandlers = {}
end

---@param cmd string
---@param cb function
function GameContextBase:setCallback(cmd, cb)
  assert(self._notificationHandlers[cmd] == nil)
  self._notificationHandlers[cmd] = cb
end

---@param cmd string
---@param cb function
function GameContextBase:setRequestHandler(cmd, cb)
  assert(self._requestHandlers[cmd] == nil)
  self._requestHandlers[cmd] = async.async(cb)
end

---@param id integer
---@return Player
function GameContextBase:getPlayerById(id)
  ---@diagnostic disable-next-line
  return tablib.find(self.players, function(p) return p.id == id end)
end

---@param seat integer
---@return Player
function GameContextBase:getPlayerBySeat(seat)
  ---@diagnostic disable-next-line
  return tablib.find(self.players, function(p) return p.seat == seat end)
end

---@param name string
---@param value any
function GameContextBase:setMark(name, value)
  self.mark[name] = value
end

---@param name string
---@return any
function GameContextBase:getMark(name)
  return self.mark[name]
end

return GameContextBase
