-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local GameContextBase = require "core.game-context"
local Engine = require "demo.chess.engine"
local tablib = ktabletop.tablib

local function pointId(x, y)
  return y * 10 + x
end

local function toSquare(x, y)
  return string.char(string.byte("a") + x - 1) .. tostring(9 - y)
end

local function promotionPiece(pawn, name)
  name = (name or "B"):upper()
  if name ~= "Q" and name ~= "R" and name ~= "B" and name ~= "N" then
    name = "B"
  end
  return pawn == "P" and name or name:lower()
end

-- starting squares of the rooks that grant a castling right
local noCastleFlagOfSquare = {
  [pointId(8, 8)] = "noCastleK",
  [pointId(1, 8)] = "noCastleQ",
  [pointId(8, 1)] = "noCastlek",
  [pointId(1, 1)] = "noCastleq",
}

---@class Chess.GameContext: GameContextBase
---@field board string[][]
local GameContext = GameContextBase:subclass("Chess.GameContext")

function GameContext:initialize()
  GameContextBase.initialize(self)
  self.board = Engine:createBoard()
end

--- Apply a move on the local board.
---@param fromX integer
---@param fromY integer
---@param x integer
---@param y integer
---@param promote? string promotion piece ("Q"/"R"/"B"/"N"), defaults to "B"
---@return string? captured piece char, or nil
function GameContext:movePieceTo(fromX, fromY, x, y, promote)
  local piece = self.board[fromY][fromX]
  local captured = self.board[y][x]
  local kind = piece:upper()

  self.board[y][x] = piece
  self.board[fromY][fromX] = Engine.empty

  -- castling: move the rook as well
  if kind == "K" and math.abs(x - fromX) == 2 then
    local rookFromX = x == 7 and 8 or 1
    local rookToX = x == 7 and 6 or 4
    self.board[fromY][rookToX] = self.board[fromY][rookFromX]
    self.board[fromY][rookFromX] = Engine.empty
  end

  -- en passant: remove the pawn that just double-stepped
  if kind == "P" and math.abs(x - fromX) == 1 and Engine:isEmpty(captured) then
    captured = self.board[fromY][x]
    self.board[fromY][x] = Engine.empty
  end

  -- promotion: a pawn reaching the back rank becomes the chosen piece
  if kind == "P" then
    local lastRank = piece == "P" and 1 or 8
    if y == lastRank then
      self.board[y][x] = promotionPiece(piece, promote)
    end
  end

  -- update castling rights
  if kind == "K" then
    if piece == "K" then
      self:setMark("noCastleK", true)
      self:setMark("noCastleQ", true)
    else
      self:setMark("noCastlek", true)
      self:setMark("noCastleq", true)
    end
  elseif kind == "R" then
    local flag = noCastleFlagOfSquare[pointId(fromX, fromY)]
    if flag then self:setMark(flag, true) end
  end
  if not Engine:isEmpty(captured) and captured:upper() == "R" then
    local flag = noCastleFlagOfSquare[pointId(x, y)]
    if flag then self:setMark(flag, true) end
  end

  -- en passant target after a pawn double-step, cleared otherwise
  if kind == "P" and math.abs(y - fromY) == 2 then
    self:setMark("passedPawn", pointId(x, (fromY + y) // 2))
  else
    self:setMark("passedPawn", nil)
  end

  if Engine:isEmpty(captured) then
    return nil
  end
  return captured
end

---@return boolean
function GameContext:canMoveTo(fromX, fromY, x, y)
  return Engine:canMoveTo(self.board, fromX, fromY, x, y)
end

--- Forsyth-Edwards Notation of the current board.
---@return string
function GameContext:getFENCode()
  local placement = table.concat(tablib.map(self.board, function(row)
    local parts = {}
    local empty = 0
    for _, piece in ipairs(row) do
      if Engine:isEmpty(piece) then
        empty = empty + 1
      else
        if empty > 0 then
          parts[#parts + 1] = tostring(empty)
          empty = 0
        end
        parts[#parts + 1] = piece
      end
    end
    if empty > 0 then
      parts[#parts + 1] = tostring(empty)
    end
    return table.concat(parts)
  end), "/")

  local active = (self.current and self.current.role == "black") and "b" or "w"

  local castling = ""
  if not self:getMark("noCastleK") then castling = castling .. "K" end
  if not self:getMark("noCastleQ") then castling = castling .. "Q" end
  if not self:getMark("noCastlek") then castling = castling .. "k" end
  if not self:getMark("noCastleq") then castling = castling .. "q" end
  if castling == "" then castling = "-" end

  local enPassant = "-"
  local passed = self:getMark("passedPawn")
  if passed then
    enPassant = toSquare(passed % 10, passed // 10)
  end

  local fullmove = self:getMark("roundCount") or 1
  local halfmove = (fullmove - 1) * 2 + (active == "w" and 0 or 1)

  return placement .. " " .. active .. " " .. castling .. " " .. enPassant
    .. " " .. halfmove .. " " .. fullmove
end

return GameContext
