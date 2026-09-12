-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local engine = require "demo.chess.engine"

ktabletop.boardgames:register {
  name = "chess",
  engine = engine,
  serverContextClass = require "demo.chess.server.game-context",
  logicClass = require "demo.chess.server.gamelogic",
  clientContextClass = require "demo.chess.client.game-context",
}

return engine
