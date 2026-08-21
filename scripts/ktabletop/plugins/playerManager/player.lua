---@class Player: Object
---@field ctx Context
---@field connId integer
local Player = class("Player")

---@param ctx Context
---@param connId integer
function Player:initialize(ctx, connId)
  self.ctx = ctx
  self.connId = connId
  self._cpp = ctx:get("__cpp.server")
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
function Player:request(command, data, timeout, timestamp, isJson)
  self._cpp.requestSocket(self.connId, command, isJson and data or json.encode(data), timeout or 0, timestamp or -1)
end

return Player
