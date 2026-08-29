local async = require "core.async"

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

---@param busyOpts? BusyOptions
---@return BusyHandle? handle nil if there is no busyState (e.g. on the server) or tracking was disabled
---@return { value: boolean }? cancelledFlag flips to true if this operation ends up cancelled by the user
function Player:_beginBusy(busyOpts)
  local busyState = self.ctx:get("busyState", nil)

  if not busyState then
    return nil, nil
  end

  if busyOpts and busyOpts.enabled == false then
    return nil, nil
  end

  local opts = tablib.assign({}, busyOpts or {})
  local cancelledFlag = { value = false }

  if opts.cancellable and not opts.onCancel then
    opts.onCancel = function()
      cancelledFlag.value = true 
      self._cpp.cancelRequest(self.connId)
    end
  end
  
  return busyState:begin(opts), cancelledFlag
end

---@param command string
---@param data any
---@param timeout? integer
---@param timestamp? integer
---@param isJson? boolean if true, should not json.encode here
---@param busyOpts? BusyOptions only meaningful on the client; ignored on the server
---@return any
function Player:request(command, data, timeout, timestamp, isJson, busyOpts)
  local handle, cancelledFlag = self:_beginBusy(busyOpts)

  local request = async.wrap(self._cpp.requestSocket)
  local ok, err, ret = async.await(request(self.connId, command, isJson and data or json.encode(data), timeout or 10, timestamp or -1))

  if handle then
    handle:finish()
  end

  -- TODO: how to properly handle error messages in request sender...
  if not ok then
    print("internal error in Player:request:", ret)

    if not (cancelledFlag and cancelledFlag.value) then
      local errorState = self.ctx:get("errorState", nil)
      if errorState then
        errorState:show(("The '%s' request was aborted: %s"):format(command, tostring(ret)), "aborted")
      end
    end
    
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
