-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

---@class ServerPlayerMixin
---@field user ServerUser
---@field ctx ServerGameContext
local ServerPlayerMixin = {}

---@class ServerPlayer: Player, ServerPlayerMixin

---@param user ServerUser
function ServerPlayerMixin:initialize(user)
  self.user = user
  self.id = user.id
  self.username = user.username
end

---@param command string
---@param data any
function ServerPlayerMixin:notify(command, data)
  self.user:notify(command, data)
end

---@param command string
---@param data any
---@param timeout? integer
---@return any
function ServerPlayerMixin:request(command, data, timeout)
  return self.user:request(command, data, timeout)
end

return ServerPlayerMixin
