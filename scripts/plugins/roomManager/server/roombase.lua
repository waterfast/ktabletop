-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomBase = require("plugins.roomManager.common.room-base")

---@class ServerRoomBase: RoomBase
local ServerRoomBase = class("ServerRoomBase", RoomBase)

---@param players Player[]
---@param command string
---@param data any
function ServerRoomBase:broadcastNotify(players, command, data)
  local jsonData = json.encode(data)
  for _, p in ipairs(players) do
    p:notify(command, jsonData, true)
  end
end

---@param command string
---@param data any
function ServerRoomBase:broadcast(command, data)
  local players = { table.unpack(self.players) }
  tablib.push(players, table.unpack(self.observers))
  self:broadcastNotify(players, command, data)
end

return ServerRoomBase
