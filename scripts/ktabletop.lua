-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

-- script executed before entering client or server script PWD should be `scripts/`

-- ktabletop is set from C++ code as global table

ktabletop.json = require "3rdparty.json"
ktabletop.class = require "3rdparty.middleclass"
ktabletop.inspect = require "3rdparty.inspect"
ktabletop.rand = require "3rdparty.xoshiro256starstar"

ktabletop.tablib = require "corelib.tablib"
ktabletop.strlib = require "corelib.strlib"

math.randomseed(os.time())

local BoardGameManager = require "core.boardgame-manager"
ktabletop.boardgames = BoardGameManager:new()

require "demo.chess"

--- Returns the game context currently in play, or nil.
---@return GameContextBase?
function ktabletop.currentGameContext()
  if ktabletop.client then
    return ktabletop.client.gameContext
  end
  return require("core.context-registry").current()
end
