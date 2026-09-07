-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop"

local Client = require "client.client"

ktabletop.client = Client:new()

local ViewModelManager = require "viewmodels.vm-manager"
local LobbyViewModel = require "viewmodels.lobby"
local CreateRoomViewModel = require "viewmodels.create-room"

ktabletop.viewModelManager = ViewModelManager:new()
ktabletop.viewModelManager:registerType("lobby", LobbyViewModel)
ktabletop.viewModelManager:registerType("create-room", CreateRoomViewModel)
