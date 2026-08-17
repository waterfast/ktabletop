-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop.ktabletop"
local Context = require "ktabletop.core.context"

local ctx = Context:new()

ctx:loadPlugin {
  name = "/ktabletop/test",
  setup = function(ctx, config)
    ctx:on("KTableTop::Context::Start", function ()
      print("Client plugin started... I want to listen on some QML signals!")
    end)
  end,
}

ctx:start()

MainContext = ctx
