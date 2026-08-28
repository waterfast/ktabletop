local Observable = require "core.observable"

---@class BusyOptions
---@field enabled? boolean set to false to skip tracking this operation entirely (default true)
---@field cancellable? boolean whether QML should offer a cancel action (default false)
---@field onCancel? fun() called when the user cancels; required if cancellable is true
---@field blocking? boolean whether this operation should lock the whole UI (default true).
---  Set to false for operations that should only show a lightweight, non-modal
---  indicator (e.g. waiting for the opponent's move) while the rest of the UI
---  (settings, leave room, ...) stays usable.

---@class BusyState: Object, Observable
---@field ctx Context
---@field count integer number of currently tracked operations
---@field blocking boolean whether at least one active operation wants a full block
---@field cancellable boolean whether the most recent cancellable operation can be cancelled
local BusyState = class("BusyState")
BusyState:include(Observable)
BusyState:registerProperty("count")
BusyState:registerProperty("blocking")
BusyState:registerProperty("cancellable")

---@param ctx Context
function BusyState:initialize(ctx)
  self.ctx = ctx
  self._stringId = "busyState"
  self.count = 0
  self.blocking = false
  self.cancellable = false
  self._blockingCount = 0
  self._cancelStack = {}

  self:createObserveObject()
end

--- Mark the start of a trackable async operation
---@param opts? BusyOptions
---@return fun() finish call exactly once, on success, error, or timeout
function BusyState:begin(opts)
  opts = opts or {}
  local isBlocking = opts.blocking

  if isBlocking == nil then
    isBlocking = true
  end

  self:setProperty("count", self.count + 1)

  if isBlocking then
    self._blockingCount = self._blockingCount + 1
    self:setProperty("blocking", true)
  end

  if opts.cancellable then
    assert(opts.onCancel, "cancellable busy operations must provide onCancel")
    self._cancelStack[#self._cancelStack + 1] = opts.onCancel
    self:setProperty("cancellable", true)
  end

  local finished = false

  return function()
    if finished then
      return
    end
    finished = true

    self:setProperty("count", self.count - 1)

    if isBlocking then
      self._blockingCount = self._blockingCount - 1
      self:setProperty("blocking", self._blockingCount > 0)
    end

    if opts.cancellable then
      tablib.removeOne(self._cancelStack, opts.onCancel)
      self:setProperty("cancellable", #self._cancelStack > 0)
    end
  end
end

function BusyState:cancel()
  local onCancel = self._cancelStack[#self._cancelStack]

  if onCancel then
    onCancel()
  end
end

return BusyState
