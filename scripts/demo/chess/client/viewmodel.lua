-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local LObject = require "corelib.lobject"
local tablib = ktabletop.tablib

---@class Chess.MainViewModel: Object, LObject
---@field context Chess.ClientGameContext
local ChessMainViewModel = ktabletop.class("Chess.MainViewModel")
ChessMainViewModel:include(LObject)

ChessMainViewModel:Property("players")
ChessMainViewModel:Property("selfId")
ChessMainViewModel:Property("selfRole")
ChessMainViewModel:Property("myTurn")
ChessMainViewModel:Property("selected")
ChessMainViewModel:Property("movablePoints")
ChessMainViewModel:Property("lastMove")
ChessMainViewModel:Property("promotion")
ChessMainViewModel:Property("gameOver")

ChessMainViewModel:Signal("SyncBoard")
ChessMainViewModel:Signal("MovePieceTo")
ChessMainViewModel:Signal("MovePieceOut")

ChessMainViewModel:Invokable("clickCell")
ChessMainViewModel:Invokable("accepted")
ChessMainViewModel:Invokable("leaveGame")
ChessMainViewModel:Invokable("requestSync")

---@param context Chess.ClientGameContext
function ChessMainViewModel:initialize(context)
  self.context = context
  self.selected = nil
  self.movablePoints = {}
  self.lastMove = nil
  self.promotion = nil

  self:setPropertyBinding("players", function()
    return tablib.map(self.context.players, function(p)
      return { id = p.id, username = p.username, role = p.role, seat = p.seat }
    end)
  end)
  self:setPropertyBinding("selfId", function()
    return ktabletop.client.myself.id
  end)
  self:setPropertyBinding("selfRole", function()
    local me = self.context:getPlayerById(ktabletop.client.myself.id)
    return me and me.role or ""
  end)
  self:setPropertyBinding("myTurn", function()
    return self.context.myTurn
  end)
  self:setPropertyBinding("gameOver", function()
    return self.context.gameOver
  end)
end

---@param x integer
---@param y integer
function ChessMainViewModel:clickCell(x, y)
  local board = self.context.board

  if self.selected then
    local movable = tablib.find(self.movablePoints, function(p)
      return p.x == x and p.y == y
    end)
    if movable then
      local piece = board[self.selected.y][self.selected.x]
      local lastRank = (piece == "P") and 1 or 8
      if piece:upper() == "P" and y == lastRank then
        self.promotion = { fromX = self.selected.x, fromY = self.selected.y, x = x, y = y }
        self:notifyPropertyChanged("promotion")
        return
      end
      self:finishMove(self.selected.x, self.selected.y, x, y, nil)
      return
    end
  end

  local piece = board[y][x]
  if piece == "." then
    self.selected = nil
    self.movablePoints = {}
    self:notifyPropertyChanged("selected")
    self:notifyPropertyChanged("movablePoints")
    return
  end

  local white = piece:find("%u") ~= nil
  local selfRole = self.selfRole
  if (white and selfRole ~= "white") or (not white and selfRole ~= "black") then
    return
  end

  self.selected = { x = x, y = y }
  local moves = {}
  for ty = 1, 8 do
    for tx = 1, 8 do
      if self.context:canMoveTo(x, y, tx, ty) then
        moves[#moves + 1] = { x = tx, y = ty }
      end
    end
  end
  self.movablePoints = moves
  self:notifyPropertyChanged("selected")
  self:notifyPropertyChanged("movablePoints")
end

---@param name string
function ChessMainViewModel:accepted(name)
  if not self.promotion then return end
  local p = self.promotion
  self.promotion = nil
  self:notifyPropertyChanged("promotion")
  self:finishMove(p.fromX, p.fromY, p.x, p.y, name)
end

function ChessMainViewModel:leaveGame()
  ktabletop.client:leaveGame()
end

function ChessMainViewModel:requestSync()
  self:emitSignal("SyncBoard", self.context.board)
end

---@param fromX integer
---@param fromY integer
---@param x integer
---@param y integer
---@param promote string?
function ChessMainViewModel:finishMove(fromX, fromY, x, y, promote)
  self.selected = nil
  self.movablePoints = {}
  self.context:submitMove({ fromX = fromX, fromY = fromY, x = x, y = y, promote = promote })
end

return ChessMainViewModel
