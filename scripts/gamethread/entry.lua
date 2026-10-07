-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop"

local GameThread = require "gamethread.gamethread"

kt.gamethread = GameThread:new()

kt.log.info("GameThread Lua VM started")

function HandleRequest(roomId, userId, command, data)
  kt.gamethread:handleRequest(roomId, userId, command, data)
end
