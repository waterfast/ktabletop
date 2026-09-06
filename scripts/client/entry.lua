-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop"

local Client = require "client.client"
local ViewModelManager = require "viewmodels.vm-manager"
local LobbyViewModel = require "viewmodels.lobby"

ktabletop.client = Client:new()
ktabletop.viewModelManager = ViewModelManager:new()
ktabletop.viewModelManager:registerType("lobby", LobbyViewModel)
