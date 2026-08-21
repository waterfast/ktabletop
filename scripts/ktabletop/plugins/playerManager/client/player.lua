--- Client-side view of a player. Only the local player's connId is
--- guaranteed valid; connIds of other players (inside a room) are for
--- identification/lookup only — the client never notifies through them.
---@class ClientPlayer: Player
local ClientPlayer = class("ClientPlayer", Player)

return ClientPlayer