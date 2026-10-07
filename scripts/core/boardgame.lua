-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local class = kt.class

---@class BoardGameSpec
---@field name string
---@field engine? table
---@field serverContextClass? Object
---@field logicClass? Object
---@field clientContextClass? Object
---@field page? { url?: string, uri?: string, name?: string }

---@class BoardGame: Object
local BoardGame = class("BoardGame")

function BoardGame:initialize(spec)
  assert(type(spec) == "table" and type(spec.name) == "string",
    "boardgame spec must have a string 'name'")
  self.name = spec.name
  self.engine = spec.engine
  self.serverContextClass = spec.serverContextClass
  self.logicClass = spec.logicClass
  self.clientContextClass = spec.clientContextClass
  self.page = spec.page
end

return BoardGame
