-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop"
local Context = require "core.context"
local async = require "core.async"

local ctx = Context:new()

ctx:loadPlugin(require "plugins.socketHelper")
ctx:loadPlugin(require "plugins.uiHelper")
ctx:loadPlugin(require "plugins.playerManager.client")
ctx:loadPlugin(require "plugins.roomManager.client")

-- dispatcher wrapped with async.sync, wrapped cb-last-param fn can be waited
ctx:on("Client::ConnectToHost", async.async(function(param)
  local uiHelper = ctx:get("uiHelper")
  uiHelper.withBusy({ message = "Connecting..." }, function ()
    local connect = async.wrap(ctx:get("__cpp.client").connectToHost)
    local _, err = async.await(connect(param.host, param.port))

    local cpp = ctx:get("__cpp.common")

    if err then 
      uiHelper.showError("Could not connect to the server: " .. tostring(err), "network")
      cpp.luaEvent("Client::ConnectError", { error = err })
    else
      cpp.luaEvent("Client::Connected", {})
    end
  end)
end))

-- Fired by UserConnection::socketError, forwarded as a lua event by
-- Client::Client() -- see src/core/client.cpp. Covers connection drops that
-- happen outside of a tracked request (e.g. mid-game disconnect).
ctx:on("Core::Socket::Error", function(param)
  ctx:get("uiHelper").showError(param.message, "network")
end)

ctx:start()

MainContext = ctx
