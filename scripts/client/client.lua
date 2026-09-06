-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local class = ktabletop.class

local ViewModelManager = require "viewmodels.vm-manager"

---@class Client: Object
local Client = class("Client")

function Client:initialize()
  self._notificationHandlers = {}
  self._requestHandlers = {}

  self.viewModelManager = ViewModelManager:new()
end

---@param cmd string
---@param cb fun(data: any)
function Client:onNotificationGot(cmd, cb)
  local list = self._notificationHandlers[cmd]
  if not list then
    list = {}
    self._notificationHandlers[cmd] = list
  end
  list[#list + 1] = cb
end

---@param cmd string
---@param cb fun(player: Player, data: any): any, string?
function Client:onRequestGot(cmd, cb)
  assert(self._requestHandlers[cmd] == nil)
  self._requestHandlers[cmd] = async.async(cb)
end

-- Called by C++ to connect to a server.
---@param host string
---@param port integer
function Client:connectToHost(host, port)
  local connect = async.async(function()
      local wrapped = async.wrap(ktabletop.connectToHost)
      local _, err = async.await(wrapped(host, port))

      if err then
        ktabletop.luaEvent("Client::ConnectError", { error = err })
      else
        ktabletop.luaEvent("Client::Connected", {})
      end
  end)
  connect()
end

-- Called by C++ when a notification arrives.
---@param connId integer
---@param command string
---@param data any
function Client:processNotification(connId, command, data)
  local list = self._notificationHandlers[command]
  if not list then
    return
  end
  for _, fn in ipairs(list) do
    fn(data)
  end
end

local requestDispatcher = async.async(function(client, connId, requestId, command, data)
  local fn = client._requestHandlers[command]
  if not fn then
    return
  end

  local player = client.playerManager.myself
  assert(player, ("cannot find player of connId %d in request #%d"):format(connId, requestId))

  local ok, reply, err = async.await(fn(player, data))
  if not ok then
    player:reply(false, requestId, reply)
  elseif err then
    player:reply(false, requestId, err)
  else
    player:reply(true, requestId, reply)
  end
end)

-- Called by C++ when a request arrives.
---@param connId integer
---@param requestId integer
---@param command string
---@param data any
function Client:processRequest(connId, requestId, command, data)
  requestDispatcher(self, connId, requestId, command, data)
end

-- Called by C++ when a socket error happens outside a tracked request.
---@param message string
function Client:onSocketError(message)
  -- self.uiHelper:showError(message, "network")
end

return Client
