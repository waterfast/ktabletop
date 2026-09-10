-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop"

local GameThread = require "gamethread.gamethread"

ktabletop.gamethread = GameThread:new()

ktabletop.log.info("GameThread Lua VM started")

function HandleRequest(roomId, playerId, command, data)
  ktabletop.gamethread:handleRequest(roomId, playerId, command, data)
end
