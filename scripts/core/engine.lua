-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

-- Engine: manage boardgames and other global, static stuff.

local class = kt.class

---@class Engine: Object
---@field games table<string, Boardgame>
local Engine = class("Engine")

function Engine:initialize()
  self.games = {}
end

---@param game Boardgame
function Engine:registerGame(game)
  if self.games[game.id] then
    kt.log.warn(("boardgame '%s' already registered, overwriting"):format(game.name))
  end
  self.games[game.id] = game
end

---@param name string?
---@return Boardgame?
function Engine:getGame(name)
  if type(name) ~= "string" then return nil end
  return self.games[name]
end

--- Returns the game context currently in play, or nil.
---@return GameContextBase
function Engine:currentGameContext()
  if kt.client then
    return kt.client.gameContext
  end
  if kt.gamethread then
    return kt.gamethread:currentGameContext()
  ---@diagnostic disable-next-line
  end
end

return Engine
