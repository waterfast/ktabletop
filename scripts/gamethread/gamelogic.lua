-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local class = kt.class
local GameEvent = require "gamethread.gameevent"

---@class GameLogic: Object
---@field ctx ServerGameContext
---@field root GameEvent
local GameLogic = class("GameLogic")

function GameLogic:initialize(ctx)
  self.ctx = ctx
end

--- root event of game
local Game = GameEvent:subclass("GameEvent.Game")
function Game:main()
  self.ctx.logic:run()
end

function GameLogic:start()
  async.run(function()
    local root = Game:new(self.ctx)
    self.root = root
    self.ctx:broadcast("Room::StartGame", { gameType = "chess" })
    local ok, errmsg = async.await(root:exec())
    local ctx = self.ctx
    if not ctx.gameFinished then
      -- root event may be killed by error?
      if not ok then
        kt.log.critical(errmsg)
      else
        kt.log.info("Game is over now because root event finished.")
      end
      ctx:gameOver()
    end
  end)
end

function GameLogic:run()
  kt.log.info("Hello, world!")
end

return GameLogic
