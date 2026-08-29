local BusyState = require "plugins.uiHelper.busy-state"
local ErrorState = require "plugins.uiHelper.error-state"
local async = require "core.async"

---@type Plugin
local M = {
  name = "/ktabletop/uiHelper",
  ifaces = { "ktabletop.uiHelper" },
}

function M.setup(ctx)
  local busyState = nil
  local function getBusyState()
    if not busyState then
      busyState = BusyState:new(ctx)
    end
    
    return busyState
  end

  local errorState = nil
  local function getErrorState()
    if not errorState then
      errorState = ErrorState:new(ctx)
    end
    
    return errorState
  end

  ---@class UiHelper
  local uiHelper = {
    --- Mark the start of a trackable async operation. See BusyState:begin.
    ---@param opts? BusyOptions
    ---@param fn fun(): ...
    ---@return ...
    withBusy = function(opts, fn)
      local handle = getBusyState():begin(opts)
      local results = table.pack(pcall(fn))
      handle:finish()

      if not results[1] then
        error(results[2], 0)
      end
      
      return table.unpack(results, 2, results.n)
    end,

    ---@param player Player
    ---@param awaitable table
    ---@param opts? BusyOptions
    ---@return any
    awaitRequest = function(player, awaitable, opts)
      local cancelled = false
      opts = tablib.assign({}, opts or {})

      if opts.cancelable and not opts.onCancel then
        opts.onCancel = function()
          cancelled = true
          local requestId = awaitable.syncResult and awaitable.syncResult[1]

          if requestId then
            player:cancelRequest(requestId)
          end
        end
      end

      local handle = getBusyState():begin(opts)
      local ok, err, ret = async.await(awaitable)
      handle:finish()

      if not ok then
        print("internal error awaiting request:", ret)

        if not cancelled then
          getErrorState():show(tostring(ret), "aborted")
        end

        return ""
      elseif err then
        print("error from the server:", ret)
        return ""
      else
        return json.decode(ret)
      end
    end,
    
    --- Show the error dialog.
    ---@param message string
    ---@param kind? ErrorKind
    showError = function(message, kind)
      getErrorState():show(message, kind)
    end,
   }
 
  ctx:set("uiHelper", uiHelper)
 
  -- QML calls Backend.emit("BusyState::CancelRequested", {}) on the cancel button.
  ctx:on("BusyState::CancelRequested", function()
    if busyState then
      busyState:cancel()
    end
  end)
 
  -- QML calls Backend.emit("ErrorState::Dismissed", {}) on the OK button.
  ctx:on("ErrorState::Dismissed", function()
    if errorState then
      errorState:dismiss()
    end
  end)
end

return M