-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local LObject = require "corelib.lobject"

---@class LobbyViewModel: Object, LObject
---@field playerCount integer
local LobbyViewModel = ktabletop.class("LobbyViewModel")
LobbyViewModel:include(LObject)

LobbyViewModel:Property("playerCount")
LobbyViewModel:Invokable("disconnectFromHost")

function LobbyViewModel:initialize()
  self.playerCount = 0
end

function LobbyViewModel:disconnectFromHost()
  ktabletop.luaEvent("Client::DisconnectFromHost", nil)
end

return LobbyViewModel
