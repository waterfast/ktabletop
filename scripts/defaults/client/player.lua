-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local Player = require "core.player"
local ClientPlayerMixin = require "client.player-mixin"

---@class DefaultClientPlayer: Player, ClientPlayerMixin
local DefaultClientPlayer = Player:subclass("DefaultClientPlayer")
DefaultClientPlayer:include(ClientPlayerMixin)

---@param user ClientUser
function DefaultClientPlayer:initialize(user)
  Player.initialize(self)
  ClientPlayerMixin.initialize(self, user)
end

return DefaultClientPlayer
