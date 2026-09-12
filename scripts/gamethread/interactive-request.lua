-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local class = ktabletop.class

---@class InteractiveRequest: Object
---@field players Player[]
---@field n integer
---@field command string
---@field data table<integer, any>
---@field defaultReply table<integer, any>
---@field timeout integer?
---@field result table<integer, any>
---@field _asked boolean?
local InteractiveRequest = class("InteractiveRequest")

---@param players Player|Player[]
---@param command string
---@param n? integer
function InteractiveRequest:initialize(players, command, n)
  if (not players[1]) and players.class then players = { players } end
  assert(#players > 0)
  self.players = players
  self.n = n or #players
  self.command = command
  self.data = {}
  self.defaultReply = {}
  self.timeout = nil
  self.result = {}
  self._asked = false
end

---@param player Player
---@param data any
function InteractiveRequest:setData(player, data)
  self.data[player.id] = data
end

---@param player Player
---@param reply any
function InteractiveRequest:setDefaultReply(player, reply)
  self.defaultReply[player.id] = reply
end

function InteractiveRequest:ask()
  if self._asked then return end
  for _, player in ipairs(self.players) do
    local reply = player:request(self.command, self.data[player.id], self.timeout)
    if reply == "" or reply == nil then
      reply = self.defaultReply[player.id]
    end
    self.result[player.id] = reply
  end
  self._asked = true
end

---@param player Player
---@return any
function InteractiveRequest:getResult(player)
  if not self._asked then self:ask() end
  return self.result[player.id]
end

return InteractiveRequest
