-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local GameContext = require "demo.chess.game-context"
local ClientGameContextMixin = require "client.game-context-mixin"

---@class Chess.ClientGameContext: Chess.GameContext
local ClientGameContext = GameContext:subclass("Chess.ClientGameContext")
ClientGameContext:include(ClientGameContextMixin)

return ClientGameContext
