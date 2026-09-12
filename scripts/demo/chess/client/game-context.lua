-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local LObject = require "corelib.lobject"
local GameContext = require "demo.chess.game-context"
local ClientGameContextMixin = require "client.game-context-mixin"
local ClientPlayer = require "demo.chess.client.player"
local Engine = require "demo.chess.engine"
local tablib = ktabletop.tablib

---@class Chess.ClientGameContext: Chess.GameContext, ClientGameContextMixin, LObject
---@field vm Chess.MainViewModel
---@field myTurn boolean
local ClientGameContext = GameContext:subclass("Chess.ClientGameContext")
ClientGameContext:include(ClientGameContextMixin)
ClientGameContext:include(LObject)

ClientGameContext:Property("players")
ClientGameContext:Property("myTurn")
ClientGameContext:Property("gameOver")

---@param gameType string
---@param data table
function ClientGameContext:initialize(gameType, data)
  GameContext.initialize(self)

  self.playerClass = ClientPlayer
  self.myTurn = false
  self.players = tablib.map(data.users or {}, function(u)
    local player = self.playerClass:new(u)
    player.ctx = self
    return player
  end)

  self:setCallback("Chess.SyncBoard", self.handleSyncBoard)
  self:setCallback("Chess.MovePieceTo", self.handleMovePieceTo)
  self:setCallback("PropertyUpdate", self.handlePropertyUpdate)
  self:setCallback("ArrangeSeats", self.handleArrangeSeats)
  self:setCallback("GameOver", self.handleGameOver)
  self:setRequestHandler("Chess.PlayChess", self.handlePlayChess)
end

function ClientGameContext:setupViewModel()
  self.vm = ktabletop.viewModelManager:getViewModel({
    type = "chess",
    params = { self },
  })
end

function ClientGameContext:handleSyncBoard(_, data)
  self.board = data.board
  self.vm:emitSignal("SyncBoard", self.board)
end

function ClientGameContext:handleMovePieceTo(_, data)
  local fromX, fromY, x, y, promote = data.fromX, data.fromY, data.x, data.y, data.promote
  local piece = self.board[fromY][fromX]
  local captured = self.board[y][x]
  local kind = piece and piece:upper()

  self:movePieceTo(fromX, fromY, x, y, promote)
  self.vm.lastMove = { fromX = fromX, fromY = fromY, x = x, y = y }

  if kind == "K" and math.abs(x - fromX) == 2 then
    local rookFromX = x == 7 and 8 or 1
    local rookToX = x == 7 and 6 or 4
    self.vm:emitSignal("MovePieceTo", {
      fromX = rookFromX,
      fromY = fromY,
      x = rookToX,
      y = fromY,
      piece = self.board[fromY][rookToX],
    })
  elseif kind == "P" and math.abs(x - fromX) == 1 and Engine:isEmpty(captured) then
    self.vm:emitSignal("MovePieceOut", { x = x, y = fromY })
  end

  self.vm:emitSignal("MovePieceTo", {
    fromX = fromX,
    fromY = fromY,
    x = x,
    y = y,
    piece = self.board[y][x],
  })
end

function ClientGameContext:handlePropertyUpdate(_, data)
  local player = self:getPlayerById(data.id)
  self:setPlayerProperty(player, data.property, data.value)
  self:notifyPropertyChanged("players")
end

function ClientGameContext:handleArrangeSeats(_, data)
  self:arrangeSeats(data.ids)
end

function ClientGameContext:handleGameOver(_, data)
  self.gameOver = data
end

---@param user ClientUser
function ClientGameContext:handlePlayChess(user, data)
  self.myTurn = true

  local wrapped = async.wrap(function(cb) self.moveCallback = cb end)
  local ok, move = async.await(wrapped())

  self.myTurn = false

  if not ok then return "" end
  return move
end

---@param move table
function ClientGameContext:submitMove(move)
  if self.moveCallback then
    local cb = self.moveCallback
    self.moveCallback = nil
    cb(nil, move)
  end
end

return ClientGameContext
