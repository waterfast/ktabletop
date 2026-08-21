local ClientLobby = require("ktabletop.plugins.roomManager.client.lobby")
local ClientRoom = require("ktabletop.plugins.roomManager.client.room")
local Commands = require("ktabletop.plugins.playerManager.common.network-commands")

local function notifyChanged(ctx)
  ctx:emit("KTableTop::Client::RoomStore::Changed", ctx:get("current"))
end

local function onEnterLobby(ctx, data)
  ctx:set("current", ClientLobby:new(ctx))
  notifyChanged(ctx)
end

local function onUpdatePlayerNum(ctx, data)
  ctx:get("current").playerCount = data[1]
  notifyChanged(ctx)
end

local function onEnterRoom(ctx, data)
  ctx:set("current", ClientRoom:new(ctx, data.id, data.name, data.capacity))
  notifyChanged(ctx)
end

local function onAddPlayer(ctx, data)
  local current = ctx:get("current")
  if current:isInstanceOf(ClientRoom) then
    current:addMember(data[1])
    notifyChanged(ctx)
  end
end

local function onRemovePlayer(ctx, data)
  local current = ctx:get("current")
  if current:isInstanceOf(ClientRoom) then
    current:removeMember(data[1])
    notifyChanged(ctx)
  end
end

local function onRoomOwner(ctx, data)
  ctx:get("current").ownerConnId = data[1]
  notifyChanged(ctx)
end

local handlers = {
  [Commands.EnterLobby] = onEnterLobby,
  [Commands.UpdatePlayerNum] = onUpdatePlayerNum,
  [Commands.EnterRoom] = onEnterRoom,
  [Commands.AddPlayer] = onAddPlayer,
  [Commands.RemovePlayer] = onRemovePlayer,
  [Commands.RoomOwner] = onRoomOwner,
}

---@type Plugin
local M = {
  name = "/ktabletop/client/roomManager",
  deps = { "/ktabletop/client/playerManager" },
}

function M.setup(ctx, config)
  ctx:set("current", ClientLobby:new(ctx))
  
  ctx:on("KTableTop::Client::RoomStore::Changed", function (param)
    local handlers = handlers[param.command]

    if handlers then
      handlers(ctx, param.data)
    end
  end)
end

return M