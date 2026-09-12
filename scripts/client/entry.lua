-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop"

local Client = require "client.client"

ktabletop.client = Client:new()

for type, model in pairs {
  ["lobby"] = require "viewmodels.lobby",
  ["create-room"] = require "viewmodels.create-room",
  ["waiting-room"] = require "viewmodels.waiting-room",
} do ktabletop.viewModelManager:registerType(type, model) end
