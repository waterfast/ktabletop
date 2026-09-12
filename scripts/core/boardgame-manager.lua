-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local class = ktabletop.class
local BoardGame = require "core.boardgame"

---@class BoardGameManager: Object
---@field games table<string, BoardGame>
local BoardGameManager = class("BoardGameManager")

function BoardGameManager:initialize()
  self.games = {}
end

---@param spec BoardGameSpec
---@return BoardGame
function BoardGameManager:register(spec)
  local game = BoardGame:new(spec)
  if self.games[game.name] then
    ktabletop.log.warn(("boardgame '%s' already registered, overwriting"):format(game.name))
  end
  self.games[game.name] = game
  return game
end

---@param name string?
---@return BoardGame?
function BoardGameManager:get(name)
  if type(name) ~= "string" then return nil end
  return self.games[name]
end

return BoardGameManager
