local async = require("core.async")

--- Common player representation
--- Only holds data both sides need; socket I/O lives in the subclasses.
---@class Player: Object
---@field ctx Context
---@field connId integer
---@field id integer
---@field username string
local Player = class("Player")

---@param ctx Context
---@param connId integer
function Player:initialize(ctx, connId)
  self.ctx = ctx
  self.connId = connId
  self.id = connId
  self._cpp = ctx:get("__cpp.common")
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
  local request = async.wrap(self._cpp.requestSocket)
  local ok, err, ret = async.await(request(self.connId, command, isJson and data or json.encode(data), timeout or 10, timestamp or -1))
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

---@param ok boolean
---@param requestId integer
---@param data any
---@param isJson? boolean if true, should not json.encode here
function Player:reply(ok, requestId, data, isJson)
  self._cpp.replySocket(self.connId, requestId, ok, isJson and data or json.encode(data))
end

return Player
