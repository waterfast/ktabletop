-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

-- Chess engine: board/piece definitions and basic move rules.
-- Board is an 8x8 char matrix: white R N B K Q P, black lowercase, '.' empty.

local class = ktabletop.class

---@class Chess.Engine: Object
---@field initialBoard string[][]
local Engine = class("Chess.Engine")

Engine.empty = "."

Engine.initialBoard = {
  { "r", "n", "b", "q", "k", "b", "n", "r" },
  { "p", "p", "p", "p", "p", "p", "p", "p" },
  { ".", ".", ".", ".", ".", ".", ".", "." },
  { ".", ".", ".", ".", ".", ".", ".", "." },
  { ".", ".", ".", ".", ".", ".", ".", "." },
  { ".", ".", ".", ".", ".", ".", ".", "." },
  { "P", "P", "P", "P", "P", "P", "P", "P" },
  { "R", "N", "B", "Q", "K", "B", "N", "R" },
}

---@return string[][]
function Engine:createBoard()
  local board = {}
  for y = 1, 8 do
    board[y] = {}
    for x = 1, 8 do
      board[y][x] = Engine.initialBoard[y][x]
    end
  end
  return board
end

---@param c string
---@return boolean
function Engine:isEmpty(c)
  return c == Engine.empty
end

---@param c string
---@return boolean
function Engine:isWhite(c)
  return c:find("%u") ~= nil
end

---@param c string
---@return string
function Engine:getColor(c)
  return self:isWhite(c) and "white" or "black"
end

local function inBoard(x, y)
  return x >= 1 and x <= 8 and y >= 1 and y <= 8
end

local function pointId(x, y)
  return y * 10 + x
end

-- target square is empty or holds an enemy piece
local function canLandOn(board, fromX, fromY, x, y)
  local target = board[y][x]
  if target == Engine.empty then return true end
  return Engine:isWhite(board[fromY][fromX]) ~= Engine:isWhite(target)
end

-- path between start and end (exclusive) is clear
local function pathClear(board, fromX, fromY, x, y)
  local dx = x - fromX
  local dy = y - fromY
  local stepX = dx == 0 and 0 or (dx > 0 and 1 or -1)
  local stepY = dy == 0 and 0 or (dy > 0 and 1 or -1)
  local cx, cy = fromX + stepX, fromY + stepY
  while cx ~= x or cy ~= y do
    if board[cy][cx] ~= Engine.empty then return false end
    cx, cy = cx + stepX, cy + stepY
  end
  return true
end

local rules = {}

function rules.R(board, fromX, fromY, x, y)
  if fromX ~= x and fromY ~= y then return false end
  if not canLandOn(board, fromX, fromY, x, y) then return false end
  return pathClear(board, fromX, fromY, x, y)
end

function rules.N(board, fromX, fromY, x, y)
  local dx, dy = math.abs(x - fromX), math.abs(y - fromY)
  if not ((dx == 2 and dy == 1) or (dx == 1 and dy == 2)) then return false end
  return canLandOn(board, fromX, fromY, x, y)
end

function rules.B(board, fromX, fromY, x, y)
  if math.abs(x - fromX) ~= math.abs(y - fromY) then return false end
  if not canLandOn(board, fromX, fromY, x, y) then return false end
  return pathClear(board, fromX, fromY, x, y)
end

function rules.Q(board, fromX, fromY, x, y)
  local dx, dy = x - fromX, y - fromY
  if dx ~= 0 and dy ~= 0 and math.abs(dx) ~= math.abs(dy) then return false end
  if not canLandOn(board, fromX, fromY, x, y) then return false end
  return pathClear(board, fromX, fromY, x, y)
end

function rules.K(board, fromX, fromY, x, y)
  local dx, dy = x - fromX, y - fromY
  local adx, ady = math.abs(dx), math.abs(dy)

  -- normal one-square move
  if adx <= 1 and ady <= 1 then
    if adx == 0 and ady == 0 then return false end
    return canLandOn(board, fromX, fromY, x, y)
  end

  -- castling: two squares along the back rank
  if ady ~= 0 or adx ~= 2 then return false end
  local white = Engine:isWhite(board[fromY][fromX])
  local backY = white and 8 or 1
  if fromY ~= backY or fromX ~= 5 or (x ~= 3 and x ~= 7) then return false end

  local ctx = ktabletop.currentGameContext()
  if not ctx then return false end
  local flag
  if white then
    flag = x == 7 and "noCastleK" or "noCastleQ"
  else
    flag = x == 7 and "noCastlek" or "noCastleq"
  end
  if ctx:getMark(flag) then return false end

  local rookX = x == 7 and 8 or 1
  if board[backY][rookX] ~= (white and "R" or "r") then return false end
  for cx = math.min(fromX, rookX) + 1, math.max(fromX, rookX) - 1 do
    if board[backY][cx] ~= Engine.empty then return false end
  end

  local enemy = white and "black" or "white"
  local step = dx > 0 and 1 or -1
  for cx = fromX, x, step do
    if Engine:isAttacked(board, cx, backY, enemy) then return false end
  end
  return true
end

function rules.P(board, fromX, fromY, x, y)
  local white = Engine:isWhite(board[fromY][fromX])
  local dir = white and -1 or 1
  local startY = white and 7 or 2
  local dx, dy = x - fromX, y - fromY

  if dx == 0 and dy == dir and board[y][x] == Engine.empty then
    return true
  end
  if dx == 0 and dy == 2 * dir and fromY == startY
    and board[fromY + dir][fromX] == Engine.empty and board[y][x] == Engine.empty then
    return true
  end
  if math.abs(dx) == 1 and dy == dir then
    if board[y][x] ~= Engine.empty then
      return canLandOn(board, fromX, fromY, x, y)
    end
    -- en passant: the skipped square holds a just-moved enemy pawn
    local captured = board[fromY][x]
    if captured == Engine.empty or captured:upper() ~= "P" or Engine:isWhite(captured) == white then
      return false
    end
    local ctx = ktabletop.currentGameContext()
    return ctx ~= nil and ctx:getMark("passedPawn") == pointId(x, y)
  end
  return false
end

---@param board string[][]
---@return boolean
function Engine:canMoveTo(board, fromX, fromY, x, y)
  if not inBoard(fromX, fromY) or not inBoard(x, y) then return false end
  local piece = board[fromY][fromX]
  if self:isEmpty(piece) then return false end
  local rule = rules[piece:upper()]
  if not rule or not rule(board, fromX, fromY, x, y) then return false end
  return not self:willBeChecked(board, fromX, fromY, x, y)
end

--- Whether the piece at (fromX, fromY) has any legal move.
---@param board string[][]
---@return boolean
function Engine:canMove(board, fromX, fromY)
  for y = 1, 8 do
    for x = 1, 8 do
      if self:canMoveTo(board, fromX, fromY, x, y) then return true end
    end
  end
  return false
end

--- Whether moving (fromX, fromY) -> (x, y) leaves own king in check.
---@param board string[][]
---@return boolean
function Engine:willBeChecked(board, fromX, fromY, x, y)
  local moved = ktabletop.tablib.clone(board, true)
  local piece = moved[fromY][fromX]
  moved[fromY][fromX] = Engine.empty
  moved[y][x] = piece

  local color = self:getColor(piece)
  local kingX, kingY = self:findKing(moved, color)
  if not kingX then return false end
  return self:isAttacked(moved, kingX, kingY, color == "white" and "black" or "white")
end

local function attacksSquare(kind, board, fromX, fromY, x, y)
  if kind == "K" then
    return math.abs(fromX - x) <= 1 and math.abs(fromY - y) <= 1 and (fromX ~= x or fromY ~= y)
  end
  if kind == "P" then
    local white = Engine:isWhite(board[fromY][fromX])
    local dir = white and -1 or 1
    if math.abs(x - fromX) ~= 1 or y - fromY ~= dir then return false end
    local target = board[y][x]
    return target ~= Engine.empty and Engine:isWhite(target) ~= white
  end
  return rules[kind](board, fromX, fromY, x, y)
end

--- Whether square (x, y) is attacked by any piece of byColor.
---@param board string[][]
---@param byColor string
---@return boolean
function Engine:isAttacked(board, x, y, byColor)
  local attackerIsWhite = byColor == "white"
  for sy = 1, 8 do
    for sx = 1, 8 do
      local piece = board[sy][sx]
      if piece ~= Engine.empty and self:isWhite(piece) == attackerIsWhite then
        if attacksSquare(piece:upper(), board, sx, sy, x, y) then return true end
      end
    end
  end
  return false
end

---@param board string[][]
---@param color string "white" | "black"
---@return integer?, integer?
function Engine:findKing(board, color)
  local king = color == "white" and "K" or "k"
  for y = 1, 8 do
    for x = 1, 8 do
      if board[y][x] == king then return x, y end
    end
  end
end

---@param board string[][]
---@param color string side being checked
---@return boolean
function Engine:isChecking(board, color)
  local kingX, kingY = self:findKing(board, color)
  if not kingX then return false end
  return self:isAttacked(board, kingX, kingY, color == "white" and "black" or "white")
end

return Engine:new()
