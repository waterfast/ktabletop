-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local class = ktabletop.class

-- TODO: event stack, recorder, cleaner, etc....

---@class GameEvent: Object
---@field room GameRoom
---@field data any
---@field func AsyncFunction?
local GameEvent = class("GameEvent")

function GameEvent:initialize(room, ...)
  self.room = room
  self.data = table.pack(...)
  if self.data.n == 1 then self.data = self.data[1] end
end

function GameEvent:main() end

---@return AsyncFunction
function GameEvent:exec()
  self.func = async.async(self.main)(self)
  return self.func
end

function GameEvent:shutdown()
  if self.func then async.cancel(self.func) end
end

return GameEvent
