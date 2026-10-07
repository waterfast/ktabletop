-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local class = kt.class

---@class BoardgameSpec
---@field id string
---@field name string?

---@class Boardgame: Object, BoardgameSpec
---@field name string
---@field serverContextClass Object
---@field clientContextClass Object
---@field page { url?: string, uri?: string, name?: string }
---@field viewModelClass Object
local Boardgame = class("Boardgame")

function Boardgame:initialize(spec)
  assert(type(spec) == "table" and type(spec.id) == "string",
    "boardgame spec must have a string 'id'")
  self.id = spec.id
  self.name = spec.name or spec.id
end

return Boardgame
