---@class Player: Object
---@field connId integer

local Player = class("Player")

---@param connId integer
---@param cpp table -- __cpp.server functable (notifySocket/requestSocket)
function Player:initialize(connId, cpp)
  self.connId = connId
  self._cpp = cpp
end

---@param command string
---@param data any
function Player:notify(command, data)
  self._cpp.notifySocket(self.connId, command, json.encode(data))
end

---@param command string
---@param data any
---@param timeout? integer
---@param timestamp? integer
function Player:request(command, data, timeout, timestamp)
  self._cpp.requestSocket(self.connId, command, json.encode(data), timeout or 0, timestamp or -1)
end

return Player