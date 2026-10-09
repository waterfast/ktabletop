-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local GameContextBase = require "core.game-context"
local LObject = require "corelib.lobject"
local ObservableTable = require "corelib.observable"
local ClientPlayer = require "client.player"
local async = require "corelib.async"
local tablib = kt.tablib

---@class ClientGameContext: GameContextBase, LObject
---@field players ClientPlayer[]
---@field observers ClientPlayer[]
---@field current ClientPlayer
---@field getPlayer fun(self, id): ClientPlayer
---@field getPlayerBySeat fun(self, seat): ClientPlayer
---@field vm GameViewModel
---@field bg Boardgame
local ClientGameContext = GameContextBase:subclass("ClientGameContext")
ClientGameContext:include(LObject)

ClientGameContext:Property("players")
ClientGameContext:Property("gameOver")

---@param boardgame Boardgame
---@param data table
function ClientGameContext:initialize(boardgame, data)
  GameContextBase.initialize(self)
  self.G = ObservableTable:new()

  assert(boardgame.viewModelClass, ("boardgame '%s' must define viewModelClass"):format(boardgame.id))
  self.bg = boardgame

  self.players = tablib.map(data and data.users or {}, function(u)
    local player = ClientPlayer:new(u)
    player.ctx = self
    return player
  end)

  for name in pairs(boardgame.publicActions) do
    self:setCallback(boardgame.id .. "." .. name, function(_, _, d)
      self:handlePublicAction(name, d)
    end)
  end

  self:setCallback("Game::setG", self.handleSetG)
  self:setCallback("Game::setPlayerG", self.handleSetPlayerG)
  self:setCallback("Game::ArrangeSeats", self.handleArrangeSeats)
  self:setCallback("Room::GameOver", function(_, u, d) self:handleGameOver(u, d) end)
end

---@param name string
---@param data table
function ClientGameContext:handlePublicAction(name, data)
  local ret = self.bg.publicActions[name](self, table.unpack(data))
  self.vm:onAction(name, data, ret)
end

---@param command string
---@param data any
function ClientGameContext:pushRequest(command, data)
  async.run(function()
    kt.client.myself:request("PushRequest", { command = command, data = data })
  end)
end

function ClientGameContext:setupViewModel()
  kt.viewModelManager:registerType(self.bg.id, self.bg.viewModelClass)
  self.vm = kt.viewModelManager:getViewModel({
    type = self.bg.id,
    params = { self },
  })
end

function ClientGameContext:handleSetG(_, data)
  self.G[data.k] = data.v
end

function ClientGameContext:handleSetPlayerG(_, data)
  local player = self:getPlayer(data.id)
  player.G[data.k] = data.v
end

function ClientGameContext:handleArrangeSeats(_, data)
  GameContextBase.arrangeSeats(self, data.ids)
  self:notifyPropertyChanged("players")
end

---@param data { winners: integer[]? }
function ClientGameContext:handleGameOver(_, data)
  local winners = (data and data.winners) or {}
  local selfId = kt.client.myself.id
  local selfWon = false
  local names = {}
  for _, id in ipairs(winners) do
    if id == selfId then selfWon = true end
    local p = self:getPlayer(id)
    names[#names + 1] = p and p.username or tostring(id)
  end

  self.gameOver = {
    result = (#winners == 0) and "draw" or (selfWon and "win" or "lose"),
    winners = names,
  }
end

return ClientGameContext
