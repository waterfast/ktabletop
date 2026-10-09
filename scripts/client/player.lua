-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local Player = require "core.player"
local ObservableTable = require "corelib.observable"

---@class ClientPlayer: Player
---@field getNext fun(self): ClientPlayer
---@field getPrev fun(self): ClientPlayer
---@field user ClientUser
---@field ctx ClientGameContext
local ClientPlayer = Player:subclass("ClientPlayer")

---@param user ClientUser
function ClientPlayer:initialize(user)
  Player.initialize(self)
  self.G = ObservableTable:new()
  self.secret = ObservableTable:new()

  self.user = user
  self.id = user.id
  self.username = user.username
end

return ClientPlayer
