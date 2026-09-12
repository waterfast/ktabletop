local async = require "corelib.async"
local class = ktabletop.class
local json = ktabletop.json

local UserManager = require "server.user-manager"
local RoomManager = require "server.room.room-manager"

---@class Server: Object
---@field userManager UserManager
---@field roomManager RoomManager
local Server = class("Server")

function Server:initialize()
  self._notificationHandlers = {}
  self._requestHandlers = {}

  self.userManager = UserManager:new(self)
  self.roomManager = RoomManager:new()
end

---@param cmd string
---@param cb fun(self: Server, user: User, data: any)
function Server:setCallback(cmd, cb)
  assert(self._notificationHandlers[cmd] == nil)
  self._notificationHandlers[cmd] = cb
end

---@param cmd string
---@param cb fun(self: Server, user: User, data: any): any, string?
function Server:setRequestHandler(cmd, cb)
  assert(self._requestHandlers[cmd] == nil)
  self._requestHandlers[cmd] = async.async(cb)
end

----------------------------------------------------------
--- Below methods are called from C++ code.
----------------------------------------------------------

---@param connId integer
function Server:processNewConnection(connId)
  async.async(function ()
    local requestFn = async.wrap(ktabletop.requestSocket)
    local ok, ret = async.await(requestFn(connId, "Auth::RequestUsername", json.encode({}), 10, -1))

    if not ok then
      ktabletop.log.warn(("connId %d: failed to request username: %s"):format(connId, ret))
      return
    end

    local data = json.decode(ret)
    local user = self.userManager:createNewUser(connId, data and data.username)
    self.roomManager.lobby:addUser(user)
  end)()
end

---@param connId integer
function Server:processDisconnected(connId)
  local user = self.userManager:findUser(connId)
  if not user then
    return
  end

  ktabletop.log.info(string.format("User %s disconnected", user.username))

  -- clear first so resumed dispatchers skip replying on a dead socket
  local requests = user.handlingRequests
  user.handlingRequests = {}
  for _, f in pairs(requests) do
    async.cancel(f)
  end

  local room = self.roomManager:findRoomOrLobby(user.roomId)
  if room then room:removeUser(user) end
  self.userManager:removeUser(connId)
end

---@param connId integer
---@param command string
---@param data any
function Server:processNotification(connId, command, data)
  local user = self.userManager:findUser(connId)
  if not user then return end

  local f = self._notificationHandlers[command]
  if f then
    return f(self, user, data)
  end

  local room = self.roomManager:findRoomOrLobby(user.roomId)
  if not room then return end

  f = room._notificationHandlers[command]
  if f then
    return f(room, user, data)
  end
end

local requestDispatcher = async.async(function(server, user, requestId, command, data)
  local fn = server._requestHandlers[command]
  local arg1 = server
  if not fn then
    local room = server.roomManager:findRoomOrLobby(user.roomId)
    if room then
      fn = room._requestHandlers[command]
      arg1 = room
    end
  end

  if not fn then
    -- must reply an error message here. the peer is waiting for reply.
    user:reply(false, requestId, ("no match requestHandler for request '%s'"):format(command))
    return
  end

  local handler = fn(arg1, user, data)
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
function Server:processRequest(connId, requestId, command, data)
  local user = self.userManager:findUser(connId)
  if not user then return end
  requestDispatcher(self, user, requestId, command, data)
end

return Server
