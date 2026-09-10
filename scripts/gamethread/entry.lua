-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop"

ktabletop.log.info("GameThread Lua VM started")

-- TODO: test
function StartGame(roomId)
  ktabletop.log.info(("GameThread: room %d starts the game"):format(roomId))
end
