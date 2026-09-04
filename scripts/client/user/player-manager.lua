-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local ClientPlayer = require "client.user.player"

local class = ktabletop.class

---@class ClientPlayerManager: Object
---@field myself ClientPlayer?
local ClientPlayerManager = class("ClientPlayerManager")

---@param client Client
function ClientPlayerManager:initialize(client)
  self.client = client
  self.myself = nil

  client:onNotificationGot("SetupPlayer", function(data)
    local selfConnId = ktabletop.getConnId()
    local p = ClientPlayer:new(selfConnId)
    p.id = data.id
    p.username = data.username

    self.myself = p
  end)
end

return ClientPlayerManager
