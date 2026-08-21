-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomBase = require("ktabletop.plugins.roomManager.roombase")

---@class Lobby: RoomBase
local Lobby = class("Lobby", RoomBase)

---@param player Player
function Lobby:addPlayer(player)
  self.players[#self.players + 1] = player
  -- TODO: should write some client-side Lua and GUI code here!
  -- Otherwise the room manager is not possible for testing
  player:notify("EnterLobby", nil)
  self:updateOnlineInfo()
end

---@param player Player
function Lobby:removePlayer(player)
  tablib.removeOne(self.players, player)
  self:updateOnlineInfo()
end

function Lobby:updateOnlineInfo()
  self:broadcast("UpdatePlayerNum", { #self.players })
end

return Lobby
