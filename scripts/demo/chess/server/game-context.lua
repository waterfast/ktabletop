-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local GameContext = require "demo.chess.game-context"
local ServerGameContextMixin = require "server.game-context-mixin"

---@class Chess.ServerGameContext: Chess.GameContext
local ServerGameContext = GameContext:subclass("Chess.ServerGameContext")
ServerGameContext:include(ServerGameContextMixin)

return ServerGameContext
