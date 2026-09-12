-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local GameContext = require "demo.chess.game-context"
local ServerGameContextMixin = require "gamethread.game-context-mixin"
local ServerPlayer = require "demo.chess.server.player"
local GameLogic = require "demo.chess.server.gamelogic"

---@class Chess.ServerGameContext: Chess.GameContext
local ServerGameContext = GameContext:subclass("Chess.ServerGameContext")
ServerGameContext:include(ServerGameContextMixin)

---@param data table
function ServerGameContext:initialize(data)
  GameContext.initialize(self)
  ServerGameContextMixin.initialize(self, data)
  self.playerClass = ServerPlayer
  self.logicClass = GameLogic
end

return ServerGameContext
