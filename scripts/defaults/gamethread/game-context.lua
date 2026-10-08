-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local GameContextBase = require "core.game-context"
local ServerGameContextMixin = require "gamethread.game-context-mixin"
local DefaultServerPlayer = require "defaults.gamethread.player"

---@class DefaultServerGameContext: GameContextBase, ServerGameContextMixin
local DefaultServerGameContext = GameContextBase:subclass("DefaultServerGameContext")
DefaultServerGameContext:include(ServerGameContextMixin)

---@param data table
---@param boardgame Boardgame
function DefaultServerGameContext:initialize(data, boardgame)
  GameContextBase.initialize(self)
  ServerGameContextMixin.initialize(self, data)

  self.playerClass = DefaultServerPlayer
  assert(boardgame and boardgame.logicClass,
    ("boardgame '%s' must define logicClass"):format(boardgame and boardgame.id or "?"))
  self.logicClass = boardgame.logicClass
end

return DefaultServerGameContext
