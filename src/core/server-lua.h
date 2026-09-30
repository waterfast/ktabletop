// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

struct lua_State;

extern "C" int luaopen_ktabletop_server(lua_State *L);
extern "C" int luaopen_ktabletop_gamethread(lua_State *L);
