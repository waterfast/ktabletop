-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local Engine = require "demo.chess.engine"

local engine = Engine:new()

ktabletop.boardgames:register {
  name = "chess",
  engine = engine,
  roomClass = require "demo.chess.server.room",
  logicClass = require "demo.chess.server.gamelogic",
  clientClass = require "demo.chess.client.client",
}

return engine
