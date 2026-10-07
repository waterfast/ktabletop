-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

-- script executed before entering client or server script PWD should be `scripts/`

-- ktabletop is set from C++ code as global table

kt.json = require "3rdparty.json"
kt.class = require "3rdparty.middleclass"
kt.inspect = require "3rdparty.inspect"
kt.rand = require "3rdparty.xoshiro256starstar"

kt.tablib = require "corelib.tablib"
kt.strlib = require "corelib.strlib"

math.randomseed(os.time())

local ViewModelManager = require "viewmodels.vm-manager"
kt.viewModelManager = ViewModelManager:new()

local Engine = require "core.engine"
kt.engine = Engine:new()

-- require "demo.chess"

--- Returns the game context currently in play, or nil.
---@return GameContextBase?
function kt.currentGameContext()
  if kt.client then
    return kt.client.gameContext
  end
  return require("core.context-registry").current()
end
