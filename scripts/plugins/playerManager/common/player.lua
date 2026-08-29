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
---@param cancelFn? fun() actual cancellation logic; required if busyOpts.cancellable and no onCancel was given directly
---@return BusyHandle? handle nil if there is no busyState (e.g. on the server) or tracking was disabled
---@return { value: boolean }? cancelledFlag flips to true if this operation ends up cancelled by the user
function Player:_beginBusy(busyOpts, cancelFn)
  local uiHelper = self.ctx:get("uiHelper", nil)

  if not uiHelper then
    return nil, nil
  end

  if busyOpts and busyOpts.enabled == false then
    return nil, nil
  end

  local opts = tablib.assign({}, busyOpts or {})
  local cancelledFlag = { value = false }

  if opts.cancellable and not opts.onCancel then
    assert(cancelFn, "cancellable busy operation must provide a cancel function")
    opts.onCancel = function()
      cancelledFlag.value = true 
      cancelFn()
    end
  end
  
  return uiHelper.beginBusy(opts), cancelledFlag
end

---@param command string
---@param data any
---@param timeout? integer
---@param timestamp? integer
---@param isJson? boolean if true, should not json.encode here
---@param busyOpts? BusyOptions only meaningful on the client; ignored on the server
---@return any
function Player:request(command, data, timeout, timestamp, isJson, busyOpts)
  local requestFn = async.wrap(self._cpp.requestSocket)
  local awaitable = requestFn(self.connId, command, isJson and data or json.encode(data), timeout or 10, timestamp or -1)

  -- awaitable.syncResult[1] is the requestId, populated synchronously by
  -- requestSocket() as soon as async.await() below actually calls it.
  local handle, cancelledFlag = self:_beginBusy(busyOpts, function()
    local requestId = awaitable.syncResult and awaitable.syncResult[1]
    if requestId then
      self._cpp.cancelRequest(self.connId, requestId)
    end
  end)

  local ok, err, ret = async.await(awaitable)

  if handle then
    handle:finish()
  end
  
  -- TODO: how to properly handle error messages in request sender...
  if not ok then
    print("internal error in Player:request:", ret)

    if not (cancelledFlag and cancelledFlag.value) then
      local uiHelper = self.ctx:get("uiHelper", nil)
      if uiHelper then
        uiHelper.showError(("The '%s' request was aborted: %s"):format(command, tostring(ret)), "aborted")
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
