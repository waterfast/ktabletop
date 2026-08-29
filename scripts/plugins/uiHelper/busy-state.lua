local Observable = require "core.observable"

---@alias BusyIndicatorKind "spinner"|"progress"

---@class BusyOptions
---@field enabled? boolean set to false to skip tracking this operation entirely (default true)
---@field message? string text shown in the busy dialog (default: a generic "waiting" message)
---@field indicator? BusyIndicatorKind "spinner" (default) or "progress"
---@field progress? number 0..1, only used when indicator == "progress"
---@field cancellable? boolean whether QML should offer a cancel action (default false)
---@field onCancel? fun() called when the user cancels; required if cancellable is true
---@field blocking? boolean whether this operation should lock the whole UI (default true).
---  Set to false for operations that should only show a lightweight, non-modal
---  indicator (e.g. waiting for the opponent's move) while the rest of the UI
---  (settings, leave room, ...) stays usable.

---@class BusyHandle
---@field setMessage fun(self: BusyHandle, message: string)
---@field setProgress fun(self: BusyHandle, progress: number)
---@field setIndicator fun(self: BusyHandle, kind: BusyIndicatorKind)
---@field finish fun(self: BusyHandle)

---@class BusyState: Object, Observable
---@field ctx Context
---@field count integer number of currently tracked operations
---@field blocking boolean whether the topmost blocking operation wants a full block
---@field cancellable boolean whether the topmost blocking operation can be cancelled
---@field message string display text of the topmost blocking operation
---@field indicator BusyIndicatorKind
---@field progress number
local BusyState = class("BusyState")
BusyState:include(Observable)
BusyState:registerProperty("count")
BusyState:registerProperty("blocking")
BusyState:registerProperty("cancellable")
BusyState:registerProperty("message")
BusyState:registerProperty("indicator")
BusyState:registerProperty("progress")

local DEFAULT_MESSAGE = "Waiting for the server..."

---@param ctx Context
function BusyState:initialize(ctx)
  self.ctx = ctx
  self._stringId = "busyState"
  self.count = 0
  self.blocking = false
  self.cancellable = false
  self.message = DEFAULT_MESSAGE
  self.indicator = "spinner"
  self.progress = 0
  self._stack = {}

  self:createObserveObject()
end

--- Recompute observable properties from the topmost entry that wants
--- blocking. Entries with blocking = false never affect these properties.
function BusyState:_refresh()
  local top = nil

  for i = #self._stack, 1, -1 do
    if self._stack[i].blocking then
      top = self._stack[i]
      break
    end
  end

  self:setProperty("blocking", top ~= nil)
  self:setProperty("cancellable", top ~= nil and top.cancellable or false)
  self:setProperty("message", top and top.message or DEFAULT_MESSAGE)
  self:setProperty("indicator", top and top.indicator or "spinner")
  self:setProperty("progress", top and top.progress or 0)
end

--- Mark the start of a trackable async operation
---@param opts? BusyOptions
---@return BusyHandle
function BusyState:begin(opts)
  opts = opts or {}

  local entry = {
    message = opts.message or DEFAULT_MESSAGE,
    indicator = opts.indicator or "spinner",
    progress = opts.progress or 0,
    cancellable = opts.cancellable or false,
    onCancel = opts.onCancel,
    blocking = (opts.blocking == nil) and true or opts.blocking,
  }

  if opts.cancellable then
    assert(entry.onCancel, "cancellable busy operations must provide onCancel")
  end

  self._stack[#self._stack + 1] = entry
  self:setProperty("count", #self._stack)
  self:_refresh()

  local busyState = self
  local finished = false

  ---@type BusyHandle
  local handle = {}
  
  function handle:setMessage(message)
    entry.message = message
    busyState:_refresh()
  end

  function handle:setProgress(progress)
    entry.progress = progress
    entry.indicator = "progress"
    busyState:_refresh()
  end

  function handle:setIndicator(kind)
    entry.indicator = kind
    busyState:_refresh()
  end
  
  --- Idempotent: safe to call more than once (e.g. once from the await
  --- continuation and once from an error path).
  function handle:finish()
    if finished then
      return
    end
    
    finished = true
    
    if tablib.removeOne(busyState._stack, entry) then
      busyState:setProperty("count", #busyState._stack)
      busyState:_refresh()
    end
  end
  
  return handle
end

--- Called from QML (via Backend.emit("BusyState::CancelRequested")) when the
--- user taps the cancel button. Cancels the topmost blocking+cancellable entry.
function BusyState:cancel()
  for i = #self._stack, 1, -1 do
    local entry = self._stack[i]
    if entry.blocking and entry.cancellable and entry.onCancel then
      entry.onCancel()
      return
    end
  end
end

return BusyState
