-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop"
local Context = require "core.context"

local ctx = Context:new()

ctx:loadPlugin(require "plugins.socketHelper")
ctx:loadPlugin(require "plugins.playerManager.server")
ctx:loadPlugin(require "plugins.roomManager.server")

ctx:start()

MainContext = ctx
