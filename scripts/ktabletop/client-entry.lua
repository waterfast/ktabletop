-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop.ktabletop"
local Context = require "ktabletop.core.context"

local ctx = Context:new()

ctx:loadPlugin(require "ktabletop.plugins.playerManager.client")
ctx:loadPlugin(require "ktabletop.plugins.roomManager.client")

local async = require("ktabletop.core.async")

-- dispatcher wrapped with async.sync, wrapped cb-last-param fn can be waited
ctx:on("KTabletop::Client::ConnectToHost", async.async(function(param)
  local connect = async.wrap(ctx:get("__cpp.client").connectToHost)
  local err = async.await(connect(param.host, param.port))
  local cpp = ctx:get("__cpp.common")
    print(err)
  if err then
    cpp.luaEvent("KTabletop::Client::ConnectError", { error = err })
  else
    cpp.luaEvent("KTabletop::Client::Connected", {})
  end
end))

-- test
ctx:on("KTabletopCpp::ObservingObject::ValueChanged", function(param)
  -- TODO: should find the object and directly set its value to new one
  print(inspect(param))
end)

ctx:start()

MainContext = ctx
