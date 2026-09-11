-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local class = ktabletop.class
local GameEvent = require "gamethread.gameevent"

---@class GameLogic: Object
---@field room GameRoom
---@field root GameEvent
local GameLogic = class("GameLogic")

function GameLogic:initialize(room)
  self.room = room
end

--- root event of game
local Game = GameEvent:subclass("GameEvent.Game")
function Game:main()
  self.room.logic:run()
end

function GameLogic:start()
  async.async(function()
    local root = Game:new(self.room)
    self.root = root
    local ok, errmsg = async.await(root:exec())
    local room = self.room
    if not room.gameFinished then
      -- root event may be killed by error?
      if not ok then
        ktabletop.log.critical(errmsg)
      else
        ktabletop.log.info("Game is over now because root event finished.")
      end
      room:gameOver()
    end
  end)()
end

function GameLogic:run()
  ktabletop.log.info("Hello, world!")
end

return GameLogic
