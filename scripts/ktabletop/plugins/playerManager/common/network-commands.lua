--- Notification command names used across the whole plugin pack.
--- Shared between server (sender) and client (receiver) so renaming a
--- command only requires touching this file.
return {
  -- generic / cross-plugin
  ErrorMsg = "ErrorMsg",

  -- room manager
  EnterLobby = "EnterLobby",
  UpdateLobby = "UpdateLobby",
  UpdatePlayerNum = "UpdatePlayerNum",
  EnterRoom = "EnterRoom",
  AddPlayer = "AddPlayer",
  RemovePlayer = "RemovePlayer",
  RoomOwner = "RoomOwner",
}