-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop"
local Context = require "core.context"

local ctx = Context:new()

ctx:loadPlugin(require "plugins.socketHelper")
ctx:loadPlugin(require "plugins.playerManager.client")
ctx:loadPlugin(require "plugins.roomManager.client")

local async = require "core.async"

-- dispatcher wrapped with async.sync, wrapped cb-last-param fn can be waited
ctx:on("Client::ConnectToHost", async.async(function(param)
  local connect = async.wrap(ctx:get("__cpp.client").connectToHost)
  local _, err = async.await(connect(param.host, param.port))
  local cpp = ctx:get("__cpp.common")
  if err then
    cpp.luaEvent("Client::ConnectError", { error = err })
  else
    cpp.luaEvent("Client::Connected", {})
  end
end))

ctx:start()

MainContext = ctx
