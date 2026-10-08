-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local Player = require "core.player"
local ServerPlayerMixin = require "gamethread.player-mixin"

---@class DefaultServerPlayer: Player, ServerPlayerMixin
local DefaultServerPlayer = Player:subclass("DefaultServerPlayer")
DefaultServerPlayer:include(ServerPlayerMixin)

---@param user ServerUser
function DefaultServerPlayer:initialize(user)
  Player.initialize(self)
  ServerPlayerMixin.initialize(self, user)
end

return DefaultServerPlayer
