-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local ClientGameRoom = require "client.room.game-room"

---@class Chess.Client: ClientGameRoom
return ClientGameRoom:subclass("Chess.Client")
