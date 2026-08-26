-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop.ktabletop"
local Context = require "ktabletop.core.context"

local ctx = Context:new()

ctx:loadPlugin(require "ktabletop.plugins.socketHelper")
ctx:loadPlugin(require "ktabletop.plugins.playerManager.server")
ctx:loadPlugin(require "ktabletop.plugins.roomManager.server")

ctx:start()

MainContext = ctx
