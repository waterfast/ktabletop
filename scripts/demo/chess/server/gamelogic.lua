-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local GameLogic = require "gamethread.gamelogic"

---@class Chess.GameLogic: GameLogic
local ChessGameLogic = GameLogic:subclass("Chess.GameLogic")

function ChessGameLogic:run()
  local ctx = self.ctx
  ktabletop.log.info(("Chess: game start (roomId=%d, players=%d)"):format(ctx.id, #ctx.players))
  for _, player in ipairs(ctx.players) do
    ktabletop.log.info(("Chess: player id=%d username=%s"):format(player.id, player.user.username))
  end
  ktabletop.log.info("Chess: main loop not implemented yet")
end

return ChessGameLogic
