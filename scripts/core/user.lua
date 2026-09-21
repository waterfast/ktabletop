-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"

local class = ktabletop.class
local json = ktabletop.json

---@alias OnlineState "invalid"|"online"|"trust"|"run"|"robot"|"offline"

---@class User: Object
---@field connId integer My socket
---@field id integer
---@field username string
---@field roomId integer
---@field state OnlineState
---@field ready boolean
---@field handlingRequests table<integer, AsyncFunction> requestId -> running handler
local User = class("User")

---@param connId integer
function User:initialize(connId)
  self.connId = connId
  self.id = connId
  self._cpp = ktabletop
  self.state = "invalid"
  self.ready = false
  self.handlingRequests = {}
end

---@param command string
---@param data any
---@param isJson? boolean if true, should not json.encode here
function User:notify(command, data, isJson)
  assert(type(data) ~= "table" or data[1] == nil, "do not use array as data!")
  if self.state ~= "online" then return end
  self._cpp.notifySocket(self.connId, command, isJson and data or json.encode(data))
end

---@param command string
---@param data any
---@param timeout? integer
---@param timestamp? integer
---@param isJson? boolean if true, should not json.encode here
---@return any
function User:request(command, data, timeout, timestamp, isJson)
  assert(type(data) ~= "table" or data[1] == nil, "do not use array as data!")
  if self.state ~= "online" then return "" end

  local requestFn = async.wrap(self._cpp.requestSocket)
  data = isJson and data or json.encode(data)
  local ok, ret = async.await(requestFn(self.connId, command, data, timeout or 10, timestamp or -1))

  if not ok then
    local err = tostring(ret)
    ktabletop.log.critical(("request(%s): error from peer"):format(command), err)
    return "", err
  else
    return json.decode(ret)
  end
end

---@param ok boolean
---@param requestId integer
---@param data any
---@param isJson? boolean if true, should not json.encode here
function User:reply(ok, requestId, data, isJson)
  self._cpp.replySocket(self.connId, requestId, ok, isJson and data or json.encode(data))
end

return User
