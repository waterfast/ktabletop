-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local GameRoom = require "gamethread.room"

---@class Chess.Room: GameRoom
return GameRoom:subclass("Chess.Room")
