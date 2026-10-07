-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

-- Engine: manage boardgames and other global, static stuff.

local class = kt.class
local BoardGame = require "core.boardgame"

---@class Engine: Object
---@field games table<string, BoardGame>
local Engine = class("Engine")

function Engine:initialize()
  self.games = {}
end

---@param spec BoardGameSpec
---@return BoardGame
function Engine:registerGame(spec)
  local game = BoardGame:new(spec)
  if self.games[game.name] then
    kt.log.warn(("boardgame '%s' already registered, overwriting"):format(game.name))
  end
  self.games[game.name] = game
  return game
end

---@param name string?
---@return BoardGame?
function Engine:getGame(name)
  if type(name) ~= "string" then return nil end
  return self.games[name]
end

return Engine
