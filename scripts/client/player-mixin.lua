-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

---@class ClientPlayerMixin
---@field user ClientUser
---@field username string
---@field ctx ClientGameContext
local ClientPlayerMixin = {}

---@class ClientPlayer: Player, ClientPlayerMixin

---@param user ClientUser
function ClientPlayerMixin:initialize(user)
  self.user = user
  self.id = user.id
  self.username = user.username
end

return ClientPlayerMixin
