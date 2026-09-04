-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local BusyState = require "client.busy-state"
local ErrorState = require "client.error-state"
local async = require "corelib.async"

local class = ktabletop.class
local json = ktabletop.json
local tablib = ktabletop.tablib

--- Client-side helper around busy/error dialogs and request tracking.
---@class UiHelper: Object
local UiHelper = class("UiHelper")

function UiHelper:initialize()
  self._busyState = nil
  self._errorState = nil
end

function UiHelper:_getBusyState()
  if not self._busyState then
    self._busyState = BusyState:new()
  end
  return self._busyState
end

function UiHelper:_getErrorState()
  if not self._errorState then
    self._errorState = ErrorState:new()
  end
  return self._errorState
end

--- Mark the start of a trackable async operation. See BusyState:begin.
---@param opts? BusyOptions
---@param fn fun(): ...
---@return ...
function UiHelper:withBusy(opts, fn)
  local handle = self:_getBusyState():begin(opts)
  local results = table.pack(pcall(fn))
  handle:finish()

  if not results[1] then
    error(results[2], 0)
  end

  return table.unpack(results, 2, results.n)
end

---@param player Player
---@param awaitable table
---@param opts? BusyOptions
---@return any
function UiHelper:awaitRequest(player, awaitable, opts)
  local cancelled = false
  opts = tablib.assign({}, opts or {})

  if opts.cancellable and not opts.onCancel then
    opts.onCancel = function()
      cancelled = true
      local requestId = awaitable.syncResult and awaitable.syncResult[1]

      if requestId then
        player:cancelRequest(requestId)
      end
    end
  end

  local handle = self:_getBusyState():begin(opts)
  local ok, err, ret = async.await(awaitable)
  handle:finish()

  if not ok then
    print("internal error awaiting request:", ret)

    if not cancelled then
      self:_getErrorState():show(tostring(ret), "aborted")
    end

    return ""
  elseif err then
    print("error from the server:", ret)
    return ""
  else
    return json.decode(ret)
  end
end

--- Show the error dialog.
---@param message string
---@param kind? ErrorKind
function UiHelper:showError(message, kind)
  self:_getErrorState():show(message, kind)
end

return UiHelper
