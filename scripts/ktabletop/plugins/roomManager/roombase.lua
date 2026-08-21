-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

---@class RoomBase: Object
---@field ctx Context
---@field id integer
---@field players Player[]
---@field observers Player[]
local RoomBase = class("RoomBase")

---@param ctx Context
function RoomBase:initialize(ctx)
  self.ctx = ctx
  self.id = 0
  self.players = {}
  self.observers = {}
end

---@param players Player[]
---@param command string
---@param data any
function RoomBase:broadcastNotify(players, command, data)
  local jsonData = json.encode(data)
  for _, p in ipairs(players) do
    p:notify(command, jsonData, true)
  end
end

---@param command string
---@param data any
function RoomBase:broadcast(command, data)
  local players = { table.unpack(self.players) }
  tablib.push(players, table.unpack(self.observers))
  self:broadcastNotify(players, command, data)
end

return RoomBase
