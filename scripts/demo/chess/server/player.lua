-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local Player = require "demo.chess.player"
local ServerPlayerMixin = require "gamethread.player-mixin"

---@class Chess.ServerPlayer: Chess.Player
local ServerPlayer = Player:subclass("Chess.ServerPlayer")
ServerPlayer:include(ServerPlayerMixin)

---@param user ServerUser
function ServerPlayer:initialize(user)
  Player.initialize(self)
  ServerPlayerMixin.initialize(self, user)
end

return ServerPlayer
