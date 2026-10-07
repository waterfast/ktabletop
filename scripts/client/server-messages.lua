local i18nc = kt.c.i18nc

local t = {
  -- TODO: reason? maybe there will be some reason in the future.
  ["lobby.create_room_failed"] = i18nc("@lua-server-messages", "Failed to create the room!"),
  ["lobby.no_such_room"] = i18nc("@lua-server-messages", "No such room."),

  ["room.full"] = i18nc("@lua-server-messages", "Room is full!"),
  ["room.not_full_start"] = i18nc("@lua-server-messages", "Room is not full yet, you may not start game for now."),
  ["room.already_started"] = i18nc("@lua-server-messages", "The game has already started!"),
  ["room.not_all_ready"] = i18nc("@lua-server-messages", "Someone is not getting ready!"),
  ["room.not_owner_add_robot"] = i18nc("@lua-server-messages", "Only the room owner can add a robot."),
  ["room.not_owner_start"] = i18nc("@lua-server-messages", "Only the room owner can start the game."),

  ["chat.empty"] = i18nc("@lua-server-messages", "Chat message cannot be empty."),
  ["chat.invalid_utf8"] = i18nc("@lua-server-messages", "Invalid chat text"),

  ["auth.internal_error"] = i18nc("@lua-server-messages", "Server internal error"),
  ["auth.handshake_failed"] = i18nc("@lua-server-messages", "Handshake failed!"),
  ["auth.invalid_credentials"] = i18nc("@lua-server-messages", "Invalid username or password"),
  ["auth.wrong_password"] = i18nc("@lua-server-messages", "Wrong password"),
}

return function(code)
  return t[code] or code
end
