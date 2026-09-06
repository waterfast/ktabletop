-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local class = ktabletop.class

local ClientPlayer = require "client.user.player"

---@class Client: Object
---@field myself ClientPlayer
local Client = class("Client")

function Client:initialize()
  self._notificationHandlers = {}
  self._requestHandlers = {}

  self.myself = ClientPlayer:new()

  self:setCallback("SetupPlayer", self.setupPlayer)
  self:setCallback("EnterLobby", self.enterLobby)
end

---@param cmd string
---@param cb fun(self: Client, data: any)
function Client:setCallback(cmd, cb)
  assert(self._notificationHandlers[cmd] == nil)
  self._notificationHandlers[cmd] = cb
end

---@param cmd string
---@param cb fun(self: Client, player: Player, data: any): any, string?
function Client:setRequestHandler(cmd, cb)
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

function Client:setupPlayer(data)
  self.myself = ClientPlayer:new()
  self.myself.id = data.id
  self.myself.username = data.username
end

function Client:enterLobby()
  ktabletop.luaEvent("Client::EnterLobby", nil)
end

------------------------------------------------------------

-- Called by C++ when a notification arrives.
---@param connId integer
---@param command string
---@param data any
function Client:processNotification(connId, command, data)
  local f = self._notificationHandlers[command]
  return f and f(self, data)
end

local requestDispatcher = async.async(function(client, connId, requestId, command, data)
  local fn = client._requestHandlers[command]
  if not fn then
    return
  end

  local player = client.playerManager.myself
  assert(player, ("cannot find player of connId %d in request #%d"):format(connId, requestId))

  local ok, reply, err = async.await(fn(ktabletop.client, player, data))
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
