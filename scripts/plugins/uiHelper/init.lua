local BusyState = require "core.busy-state"
local ErrorState = require "core.error-state"

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
    ---@return BusyHandle
    beginBusy = function(opts)
      return getBusyState():begin(opts)
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