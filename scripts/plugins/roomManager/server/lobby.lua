-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomBase = require "plugins.roomManager.server.roombase"
local Commands = require "plugins.playerManager.common.network-commands"

---@class Lobby: ServerRoomBase
local Lobby = RoomBase:subclass("Lobby")

---@param player ServerPlayer
function Lobby:addPlayer(player)
  RoomBase.addPlayer(self, player)
  -- TODO: should write some client-side Lua and GUI code here!
  -- Otherwise the room manager is not possible for testing
  player:notify(Commands.EnterLobby, nil)
  self:updateOnlineInfo()
end

---@param player ServerPlayer
function Lobby:removePlayer(player)
  RoomBase.removePlayer(self, player)
  self:updateOnlineInfo()
end

function Lobby:updateOnlineInfo()
  self:broadcast(Commands.UpdatePlayerNum, { #self.players })
end

return Lobby
