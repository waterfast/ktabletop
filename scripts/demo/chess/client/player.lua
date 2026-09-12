-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local Player = require "demo.chess.player"
local ClientPlayerMixin = require "client.player-mixin"

---@class Chess.ClientPlayer: Chess.Player
local ClientPlayer = Player:subclass("Chess.ClientPlayer")
ClientPlayer:include(ClientPlayerMixin)

return ClientPlayer
