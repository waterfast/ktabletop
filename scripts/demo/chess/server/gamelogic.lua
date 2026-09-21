-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local GameLogic = require "gamethread.gamelogic"
local InteractiveRequest = require "gamethread.interactive-request"
local Engine = require "demo.chess.engine"

---@class Chess.GameLogic: GameLogic
---@field ctx Chess.ServerGameContext
local ChessGameLogic = GameLogic:subclass("Chess.GameLogic")

---@param ctx Chess.ServerGameContext
---@param color string
---@return boolean
local function hasLegalMove(ctx, color)
  for y = 1, 8 do
    for x = 1, 8 do
      local piece = ctx.board[y][x]
      if piece ~= Engine.empty then
        local white = Engine:isWhite(piece)
        if (white and color == "white") or (not white and color == "black") then
          if Engine:canMove(ctx.board, x, y) then
            return true
          end
        end
      end
    end
  end
  return false
end

---@param ctx Chess.ServerGameContext
---@param color string
---@return table?
local function randomMove(ctx, color)
  local board = ctx.board
  local moves = {}
  for fromY = 1, 8 do
    for fromX = 1, 8 do
      local piece = board[fromY][fromX]
      if piece ~= Engine.empty and Engine:getColor(piece) == color then
        for y = 1, 8 do
          for x = 1, 8 do
            if Engine:canMoveTo(board, fromX, fromY, x, y) then
              moves[#moves + 1] = { fromX = fromX, fromY = fromY, x = x, y = y }
            end
          end
        end
      end
    end
  end
  if #moves == 0 then return nil end
  local move = moves[math.random(#moves)]
  local piece = board[move.fromY][move.fromX]
  if piece:upper() == "P" and (move.y == 1 or move.y == 8) then
    move.promote = ({ "Q", "R", "B", "N" })[math.random(4)]
  end
  return move
end

---@param ctx Chess.ServerGameContext
---@param role string
---@return integer[]
local function winningPlayerIds(ctx, role)
  local ids = {}
  for _, p in ipairs(ctx.players) do
    if p.role == role then ids[#ids + 1] = p.id end
  end
  return ids
end

function ChessGameLogic:run()
  local ctx = self.ctx

  ctx:arrangeSeats()
  ctx:setPlayerProperty(ctx.players[1], "role", "white")
  ctx:setPlayerProperty(ctx.players[2], "role", "black")
  ctx:syncBoard()

  local current = ctx.players[1]
  local turn = 0
  while not ctx.gameFinished do
    turn = turn + 1

    local req = InteractiveRequest:new(current, "Chess.PlayChess")
    req.timeout = 90
    req:setData(current, { role = current.role })
    req:setDefaultReply(current, randomMove(ctx, current.role))

    ctx:broadcast("Chess.TurnStart", { id = current.id, duration = req.timeout })
    local result = req:getResult(current)
    ctx:broadcast("Chess.TurnStop", { id = current.id })

    if not result then
      ctx:gameOver()
      return
    end

    ctx:movePieceTo(result.fromX, result.fromY, result.x, result.y, result.promote)
    ctx:broadcast("Chess.MovePieceTo", {
      fromX = result.fromX,
      fromY = result.fromY,
      x = result.x,
      y = result.y,
      promote = result.promote,
    })

    current = current.next
    if not hasLegalMove(ctx, current.role) then
      if Engine:isChecking(ctx.board, current.role) then
        local winner = current.role == "white" and "black" or "white"
        ctx:gameOver({ winners = winningPlayerIds(ctx, winner) })
      else
        ctx:gameOver()
      end
      return
    end
  end
end

return ChessGameLogic
