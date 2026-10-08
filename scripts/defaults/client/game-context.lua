-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local GameContextBase = require "core.game-context"
local ClientGameContextMixin = require "client.game-context-mixin"
local LObject = require "corelib.lobject"
local DefaultClientPlayer = require "defaults.client.player"
local tablib = kt.tablib

---@class DefaultClientGameContext: GameContextBase, ClientGameContextMixin, LObject
---@field gameType string
---@field viewModelClass any
local DefaultClientGameContext = GameContextBase:subclass("DefaultClientGameContext")
DefaultClientGameContext:include(ClientGameContextMixin)
DefaultClientGameContext:include(LObject)

---@param gameType string
---@param data table
function DefaultClientGameContext:initialize(gameType, data)
  GameContextBase.initialize(self)
  self.gameType = gameType
  self.playerClass = DefaultClientPlayer

  local bg = assert(kt.engine:getGame(gameType),
    ("unknown boardgame '%s'"):format(tostring(gameType)))
  assert(bg.viewModelClass,
    ("boardgame '%s' must define viewModelClass"):format(gameType))
  self.viewModelClass = bg.viewModelClass

  self.players = tablib.map(data and data.users or {}, function(u)
    local player = self.playerClass:new(u)
    player.ctx = self
    return player
  end)
end

function DefaultClientGameContext:setupViewModel()
  kt.viewModelManager:registerType(self.gameType, self.viewModelClass)
  self.vm = kt.viewModelManager:getViewModel({
    type = self.gameType,
    params = { self },
  })
end

return DefaultClientGameContext
