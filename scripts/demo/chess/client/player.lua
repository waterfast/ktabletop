-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local Player = require "demo.chess.player"
local ClientPlayerMixin = require "client.player-mixin"

---@class Chess.ClientPlayer: Chess.Player, ClientPlayerMixin
local ClientPlayer = Player:subclass("Chess.ClientPlayer")
ClientPlayer:include(ClientPlayerMixin)

---@param user ClientUser
function ClientPlayer:initialize(user)
  Player.initialize(self)
  ClientPlayerMixin.initialize(self, user)
end

return ClientPlayer
