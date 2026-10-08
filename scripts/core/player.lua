-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local class = kt.class

---@class Player: Object
---@field id integer
---@field username string
---@field role string
---@field seat integer
---@field next Player
---@field G table<string, any> public state of this player
---@field secret table<string, any> private state, only synced to this player
local Player = class("Player")

function Player:initialize()
  self.id = 0
  self.role = ""
  self.seat = 0
  self.next = nil
  self.G = {}
  self.secret = {}
end

return Player
