-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local LObject = require "corelib.lobject"

---@class LobbyViewModel: LObject
---@field playerCount integer
local LobbyViewModel = ktabletop.class("LobbyViewModel")
LobbyViewModel:include(LObject)
LobbyViewModel:Property("playerCount")

function LobbyViewModel:initialize()
  self.playerCount = 0
end

return LobbyViewModel
