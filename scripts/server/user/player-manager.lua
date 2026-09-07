-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local ServerPlayer = require "server.user.player"

local class = ktabletop.class

---@class PlayerManager: Object
---@field private players table<integer, ServerPlayer>
local PlayerManager = class("PlayerManager")

---@param server Server
function PlayerManager:initialize(server)
  self.server = server
  self.players = {}
end

---@param connId integer
---@return ServerPlayer
function PlayerManager:createNewPlayer(connId)
  local player = ServerPlayer:new(connId)
  player.id = connId
  player.username = "guest" .. connId

  self:addPlayer(player)
  player:notify("SetupPlayer", { id = player.id, username = player.username })
  return player
end

---@param player ServerPlayer
function PlayerManager:addPlayer(player)
  self.players[player.connId] = player
end

---@param connId integer
function PlayerManager:removePlayer(connId)
  self.players[connId] = nil
end

---@param connId integer
---@return ServerPlayer?
function PlayerManager:findPlayer(connId)
  return self.players[connId]
end

return PlayerManager
