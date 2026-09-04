// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

struct lua_State;

// Registers the `ktabletop` global table containing the C++ backend
// infrastructure (socket I/O, timers and event bridging). Must be called after
// the LuaBinding is created (so the state can be discovered via
// LuaBinding::forState) and before the entry script is executed.
extern "C" int luaopen_ktabletop(lua_State *L);
