-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local GameContextBase = require "core.game-context"
local LObject = require "corelib.lobject"
local ClientPlayer = require "client.player"
local tablib = kt.tablib

---@class ClientGameContext: GameContextBase, LObject
---@field vm LObject?
---@field gameType string
---@field viewModelClass any
---@field bg Boardgame
local ClientGameContext = GameContextBase:subclass("ClientGameContext")
ClientGameContext:include(LObject)

ClientGameContext:Property("players")

---@param gameType string
---@param data table
function ClientGameContext:initialize(gameType, data)
  GameContextBase.initialize(self)
  self.gameType = gameType

  local bg = assert(kt.engine:getGame(gameType),
    ("unknown boardgame '%s'"):format(tostring(gameType)))
  assert(bg.viewModelClass,
    ("boardgame '%s' must define viewModelClass"):format(gameType))
  self.viewModelClass = bg.viewModelClass
  self.bg = bg

  self.players = tablib.map(data and data.users or {}, function(u)
    local player = ClientPlayer:new(u)
    player.ctx = self
    return player
  end)

  for name in pairs(bg.publicActions) do
    self:setCallback(gameType .. "." .. name, function(_, _, d)
      self:handlePublicAction(name, d)
    end)
  end
end

---@param name string
---@param data table
function ClientGameContext:handlePublicAction(name, data)
  local ret = self.bg.publicActions[name](self, table.unpack(data))
  self.vm:onAction(name, data, ret)
end

function ClientGameContext:setupViewModel()
  kt.viewModelManager:registerType(self.gameType, self.viewModelClass)
  self.vm = kt.viewModelManager:getViewModel({
    type = self.gameType,
    params = { self },
  })
end

---@param player ClientPlayer
---@param property string
---@param value any
function ClientGameContext:setPlayerProperty(player, property, value)
  player.G[property] = value
end

---@param ids integer[]
function ClientGameContext:arrangeSeats(ids)
  local players = {}
  for i, id in ipairs(ids) do
    local player = self:getPlayerById(id)
    if player then
      player.seat = i
      players[i] = player
    end
  end
  for i = 1, #players do
    players[i].next = players[i + 1] or players[1]
  end
  self.players = players
end

return ClientGameContext
