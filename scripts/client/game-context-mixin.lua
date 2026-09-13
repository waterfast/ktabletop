-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

---@class ClientGameContextMixin
---@field vm LObject?
---@field playerClass any
local ClientGameContextMixin = {}

-- pseudo class of actual ClientGameCtx
---@class ClientGameContext: GameContextBase, ClientGameContextMixin

function ClientGameContextMixin:setupViewModel()
  error("setupViewModel must be implemented")
end

---@param user ClientUser
---@return ClientPlayer
function ClientGameContextMixin:createPlayer(user)
  return self.playerClass:new(user)
end

---@param ids integer[]
function ClientGameContextMixin:arrangeSeats(ids)
  local players = {}
  for i, id in ipairs(ids) do
    local player = self:getPlayerById(id)
    if player then
      player.seat = i
      players[i] = player
    end
  end
  for i = 1, #players do
    players[i].next = players[i + 1] or players[1]
  end
  self.players = players
end

---@param player ClientPlayer
---@param property string
---@param value any
function ClientGameContextMixin:setPlayerProperty(player, property, value)
  player[property] = value
end

return ClientGameContextMixin
