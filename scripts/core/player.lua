local async = require "corelib.async"

local class = ktabletop.class
local json = ktabletop.json

---@class Player: Object
---@field connId integer My socket
---@field id integer
---@field username string
---@field roomId integer
local Player = class("Player")

---@param connId integer
function Player:initialize(connId)
  self.connId = connId
  self.id = connId
  self._cpp = ktabletop
end

---@param command string
---@param data any
---@param isJson? boolean if true, should not json.encode here
function Player:notify(command, data, isJson)
  self._cpp.notifySocket(self.connId, command, isJson and data or json.encode(data))
end

---@param command string
---@param data any
---@param timeout? integer
---@param timestamp? integer
---@param isJson? boolean if true, should not json.encode here
---@return any
function Player:request(command, data, timeout, timestamp, isJson)
  local requestFn = async.wrap(self._cpp.requestSocket)
  data = isJson and data or json.encode(data)
  local ok, err, ret = async.await(requestFn(self.connId, command, data, timeout or 10, timestamp or -1))

  -- TODO: how to properly handle error messages in request sender...
  if not ok then
    print("internal error in Player:request:", ret)
    return ""
  elseif err then
    print("error from the server in Player:request:", ret)
    return ""
  else
    return json.decode(ret)
  end
end

-- Cancel a request previously started via Player:asyncRequest, by its
--- requestId (awaitable.syncResult[1]).
---@param requestId integer
function Player:cancelRequest(requestId)
  self._cpp.cancelRequest(self.connId, requestId)
end

---@param ok boolean
---@param requestId integer
---@param data any
---@param isJson? boolean if true, should not json.encode here
function Player:reply(ok, requestId, data, isJson)
  self._cpp.replySocket(self.connId, requestId, ok, isJson and data or json.encode(data))
end

return Player
