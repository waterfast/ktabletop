-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local Player = require "demo.chess.player"
local ServerPlayerMixin = require "server.player-mixin"

---@class Chess.ServerPlayer: Chess.Player
local ServerPlayer = Player:subclass("Chess.ServerPlayer")
ServerPlayer:include(ServerPlayerMixin)

return ServerPlayer
