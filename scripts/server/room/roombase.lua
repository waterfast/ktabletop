-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomBase = require "core.room-base"

local json = ktabletop.json
local tablib = ktabletop.tablib
local utf8 = require("utf8")

local MAX_CHAT_LENGTH = 500

---@class ServerRoomBase: RoomBase
---@field players ServerPlayer[]
---@field observers ServerPlayer[]
local ServerRoomBase = RoomBase:subclass("ServerRoomBase")

function ServerRoomBase:initialize()
  RoomBase.initialize(self)
    self:setRequestHandler("Room::Chat", self.handleChat)
end

---@param players Player[]
---@param command string
---@param data any
function ServerRoomBase:broadcastNotify(players, command, data)
  local jsonData = json.encode(data)
  for _, p in ipairs(players) do
    p:notify(command, jsonData, true)
  end
end

---@param command string
---@param data any
function ServerRoomBase:broadcast(command, data)
  local players = { table.unpack(self.players) }
  tablib.push(players, table.unpack(self.observers))
  self:broadcastNotify(players, command, data)
end

---@param player ServerPlayer
---@param data { text: string }
function ServerRoomBase:handleChat(player, data)
  local text = data and data.text

  if type(text) ~= "string" or text == "" then
    return nil, "chat message cannot be empty"
  end
  
  local char_count = utf8.len(text)
  if not char_count then
    return nil, "invalid UTF-8 string"
  end

  if char_count > MAX_CHAT_LENGTH then
    local offset = utf8.offset(text, MAX_CHAT_LENGTH + 1)

    if offset then
      text = text:sub(1, offset - 1)
    end
  end

  self:broadcast("Room::ChatMessage", {
    id = player.id,
    username = player.username,
    text = text,
    timestamp = os.time()
  })
end

return ServerRoomBase
