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
function PlayerManager:createNewPlayer(connId, username)
  local player = ServerPlayer:new(connId)
  player.id = connId
  player.username = (username ~= nil and username ~= "") and username or ("guest" .. connId)
  player.state = "online"

  self:addPlayer(player)
  player:notify("Player::Setup", { id = player.id, username = player.username })
  return player
end

local nextRobotId = -2
function PlayerManager:createRobot()
  local robot = ServerPlayer:new(0)
  robot.state = "robot"
  robot.id = nextRobotId
  nextRobotId = nextRobotId - 1
  robot.username = ("COMP%d"):format(robot.id)
  -- TODO: ready = true

  self:addPlayer(robot)
  return robot
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
