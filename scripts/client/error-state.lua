local Observable = require "corelib.observable"

local class = ktabletop.class

---@alias ErrorKind "network"|"aborted"|"luaError"

---@class ErrorState: Object, Observable
---@field active boolean
---@field message string
---@field kind ErrorKind
local ErrorState = class("ErrorState")
ErrorState:include(Observable)
ErrorState:registerProperty("active")
ErrorState:registerProperty("message")
ErrorState:registerProperty("kind")

function ErrorState:initialize()
  self._stringId = "errorState"
  self.active = false
  self.message = ""
  self.kind = "aborted"

  self:createObserveObject()
end

---@param message string
---@param kind? ErrorKind defaults to "aborted"
function ErrorState:show(message, kind)
  self:setProperty("message", message)
  self:setProperty("kind", kind or "aborted")
  self:setProperty("active", true)
end

--- Called from QML when the user dismisses the error dialog (OK button).
function ErrorState:dismiss()
  self:setProperty("active", false)
end

return ErrorState
