-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop"
local Context = require "core.context"
local BusyState = require "core.busy-state"
local async = require "core.async"

local ctx = Context:new()

ctx:loadPlugin(require "plugins.socketHelper")
ctx:loadPlugin(require "plugins.playerManager.client")
ctx:loadPlugin(require "plugins.roomManager.client")

-- busyState is set "after" the cpp plugins load (it needs __cpp.common through
-- Observable), but before any request can happen, since connecting is the
-- first thing that can go through the busy dialog.
local busyState = nil
local function getBusyState()
  if not busyState then
    busyState = BusyState:new(ctx)
    ctx:set("busyState", busyState)
  end

  return busyState
end

-- dispatcher wrapped with async.sync, wrapped cb-last-param fn can be waited
ctx:on("Client::ConnectToHost", async.async(function(param)
  local finishBusy = getBusyState():begin()
  local connect = async.wrap(ctx:get("__cpp.client").connectToHost)
  local _, err = async.await(connect(param.host, param.port))
  finishBusy()

  local cpp = ctx:get("__cpp.common")
  if err then
    cpp.luaEvent("Client::ConnectError", { error = err })
  else
    cpp.luaEvent("Client::Connected", {})
  end
end))

-- QML calls Backend.emit("BusyState::CancelRequested", {}) when the user taps
-- the cancel button on the busy dialog.
ctx:on("BusyState::CancelRquested", function()
  getBusyState():cancel()
end)

ctx:start()

MainContext = ctx
