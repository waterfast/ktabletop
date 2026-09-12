-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local class = ktabletop.class

---@class Player: Object
---@field id integer
---@field role string
---@field seat integer
---@field next Player?
---@field mark table<string, any>
local Player = class("Player")

function Player:initialize()
  self.id = 0
  self.role = ""
  self.seat = 0
  self.next = nil
  self.mark = {}
end

---@param name string
---@return any
function Player:getMark(name)
  return self.mark[name]
end

---@param name string
---@param value any
function Player:setMark(name, value)
  self.mark[name] = value
end

return Player
