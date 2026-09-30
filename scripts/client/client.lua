-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local class = ktabletop.class
local translateServerMessage = require "client.server-messages"

local ClientUser = require "client.user"
local ClientLobby = require "client.lobby"
local ClientRoom = require "client.room"

---@class Client: Object
---@field myself ClientUser
---@field lobby ClientLobby
---@field room ClientRoom
---@field gameContext ClientGameContext
local Client = class("Client")

function Client:initialize()
  self._notificationHandlers = {}
  self._requestHandlers = {}
  self.pendingUsername = ""
  self.pendingPassword = ""

  self.myself = ClientUser:new()
  self.lobby = ClientLobby:new()

  ---- Handshake and auth stuff ----
  self:setRequestHandler("Auth::RequestNonce", self.handleNonceRequest)
  self:setRequestHandler("Auth::ExchangeKey", self.handleExchangeKey)
  self:setCallback("Auth::StartEncryption", self.startEncryption)
  self:setRequestHandler("Auth::RequestUsername", self.handleAuthRequest)
  self:setCallback("User::Setup", self.setupUser)

  self:setCallback("App::ErrorDialog", self.handleErrorDialog)
  self:setCallback("App::ShowToast", self.handleShowToast)

  self:setCallback("Lobby::Enter", self.enterLobby)

  self:setCallback("Room::Enter", self.enterRoom)
  self:setCallback("Room::StartGame", self.startGame)

end

---@param cmd string
---@param cb fun(self: Client, user: User, data: any)
function Client:setCallback(cmd, cb)
  assert(self._notificationHandlers[cmd] == nil)
  self._notificationHandlers[cmd] = cb
end

---@param cmd string
---@param cb fun(self: Client, user: User, data: any): any, string?
function Client:setRequestHandler(cmd, cb)
  assert(self._requestHandlers[cmd] == nil)
  self._requestHandlers[cmd] = async.async(cb)
end

-- helper functions that does work from userManager & roomManager
-- since there's only one special user (myself) and my room

function Client:setupUser(_, data)
  self.myself = ClientUser:new()
  self.myself.connId = 1001
  self.myself.id = data.id
  self.myself.state = "online"
  self.myself.username = data.username
end

function Client:enterLobby()
  self.myself.roomId = 0
  self.room = nil

  self.lobby:setupViewModel()

  ktabletop.luaEvent("Client::EnterLobby", {
    viewModelName = self.lobby.vm._stringId,
  })
end

function Client:enterRoom(_, data)
  local room = ClientRoom:new()
  room.id = data.id
  room.name = data.name
  room.capacity = data.capacity

  self.room = room

  room:addUser(self.myself)
  room:setupViewModel()

  data.viewModelName = room.vm._stringId
  ktabletop.luaEvent("Client::EnterRoom", data)
end

---@param data table
function Client:startGame(_, data)
  self:enterGame(data.gameType, {
    users = self.room and self.room.users or {},
  })
end

---@param gameType string?
---@param data table?
function Client:enterGame(gameType, data)
  gameType = gameType or "chess"
  local bg = ktabletop.boardgames:get(gameType)
  local klass = bg and bg.clientContextClass
  assert(klass, ("no clientContextClass for boardgame '%s'"):format(gameType))

  self.gameContext = klass:new(gameType, data)
  self.gameContext:setupViewModel()

  ktabletop.luaEvent("Client::EnterGame", {
    viewModelName = self.gameContext.vm._stringId,
    pageUrl = bg.page and bg.page.url or "",
  })
end

function Client:leaveGame()
  self.gameContext = nil
  ktabletop.luaEvent("Client::LeaveGame", nil)
end

function Client:handleAuthRequest(_, _)
  return { username = self.pendingUsername, password = self.pendingPassword }
end

function Client:handleNonceRequest(_, _)
  return ktabletop.getClientNonce()
end

function Client:handleExchangeKey(user, data)
  local clientPub = ktabletop.verifyAuthChallenge(data.idPub, data.serverPub, data.sig)
  if clientPub == "" then
    ktabletop.disconnect(user.connId)
    return ""
  end
  return clientPub
end

function Client:startEncryption(_, _)
  if not ktabletop.acceptServerKey() then
    ktabletop.disconnect(0)
  end
end

function Client:showErrorDialog(message)
  ktabletop.showErrorDialog(message)
end

function Client:showToast(message)
  ktabletop.showToast(message)
end

function Client:handleErrorDialog(_, code)
  self:showErrorDialog(translateServerMessage(code))
end

function Client:handleShowToast(_, code)
  self:showToast(translateServerMessage(code))
end

----------------------------------------------------------
--- Below methods are called from C++ code.
----------------------------------------------------------

local function waitForRequestGot(tp)
  local ok, ret = async.await(async.wrap(function(cb)
    ktabletop.client.waitForRequestGotCb = cb
    return function() cb(async.CANCELLED) end
  end)())
  if not ok then return ok, ret end
  if ret ~= tp then return false, ("Unexpected request: expect %s, got %s"):format(tp, ret) end
  return ok, ret
end

---@param self Client
local function connectToHost(self, host, port)
  local ok, ret
  local success = false
  ktabletop.startTask("connectToHost", ktabletop.i18n("Connecting to host..."), -1, true, async.abort())
  local defer <close> = setmetatable({}, { __close = function()
    ktabletop.updateTask("connectToHost", 100)
    if success then return end
    ktabletop.log.warn(("Failed to connect to %s:%d - %s"):format(host, port, tostring(ret)))
    self:disconnectFromHost()
  end})
  ok, ret = async.await(async.wrap(ktabletop.connectToHost)(host, port))
  if not ok then
    -- ktabletop.log.warn(("Failed to connect to %s:%d - %s"):format(host, port, tostring(ret)))
    return
  end

  ok, ret = waitForRequestGot("Auth::RequestNonce")
  if not ok then return end
  ktabletop.updateTask("connectToHost", -1, ktabletop.i18n("Sending nonce to server..."))

  ok, ret = waitForRequestGot("Auth::ExchangeKey")
  if not ok then return end
  ktabletop.updateTask("connectToHost", -1, ktabletop.i18n("Exchanging keys..."))

  ok, ret = waitForRequestGot("Auth::RequestUsername")
  if not ok then return end

  success = true
end

---@param host string
---@param port integer
function Client:connectToHost(host, port, username, password)
  self.pendingUsername = username or ""
  self.pendingPassword = password or ""
  async.run(connectToHost, self, host, port)
end

-- TODO: use similar logic of server side
-- oh code cloning detected here!

---@param connId integer
---@param command string
---@param data any
function Client:processNotification(connId, command, data)
  local user = self.myself
  if not user then return end

  local f = self._notificationHandlers[command]
  if f then
    return f(self, user, data)
  end

  if self.gameContext then
    f = self.gameContext._notificationHandlers[command]
    if f then
      return f(self.gameContext, user, data)
    end
  end

  local room = user.roomId == 0 and self.lobby or self.room
  if not room then return end

  f = room._notificationHandlers[command]
  if f then
    return f(room, user, data)
  end
end

local requestDispatcher = async.async(function(client, connId, requestId, command, data, timeout)
  local user = client.myself
  assert(user, ("cannot find user of connId %d in request #%d"):format(connId, requestId))
  user.connId = connId

  if client.waitForRequestGotCb then
    local cb = client.waitForRequestGotCb
    client.waitForRequestGotCb = nil
    cb(nil, command)
  end

  local arg1 = client
  local fn = client._requestHandlers[command]
  if not fn then
    if client.gameContext then
      fn = client.gameContext._requestHandlers[command]
      arg1 = client.gameContext
    end
  end
  if not fn then
    local room = user.roomId == 0 and client.lobby or client.room
    if room then
      fn = room._requestHandlers[command]
      arg1 = room
    end
  end

  if not fn then
    return
  end

  local handler = fn(arg1, user, data, timeout)
  user.handlingRequests[requestId] = handler
  local ok, reply = async.await(handler)

  -- canceled by the peer: the registry entry has been removed, do not reply
  if user.handlingRequests[requestId] == nil then
    return
  end
  user.handlingRequests[requestId] = nil

  if not ok then
    user:reply(false, requestId, reply)
  else
    user:reply(true, requestId, reply)
  end
end)

---@param connId integer
---@param requestId integer
---@param command string
---@param data any
function Client:processRequest(connId, requestId, command, data, timeout)
  requestDispatcher(self, connId, requestId, command, data, timeout)
end

---@param message string
function Client:onSocketError(message)
  -- self.uiHelper:showError(message, "network")
  ktabletop.showErrorDialog(message)
  ktabletop.luaEvent("Client::SocketError", nil)

  -- TODO: should stop all async tasks here.
  if self.waitForRequestGotCb then
    local cb = self.waitForRequestGotCb
    self.waitForRequestGotCb = nil
    cb(message)
  end

end

function Client:disconnectFromHost()
  ktabletop.disconnect(0)
end

return Client
