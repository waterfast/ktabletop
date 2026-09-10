// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

// wrapper classes for Lua and Git2

#include <QHash>
#include <QMutex>
#include <QThread>
#include <QVariant>
#include <lua.hpp>

class LuaVM
{
public:
    explicit LuaVM();
    LuaVM(LuaVM &) = delete;
    LuaVM(LuaVM &&) = delete;
    ~LuaVM();

    lua_State *state() const;

    bool dofile(const QString &path);
    void dumpStack();

    QVariant call(const QString &func_name, QVariantList params = QVariantList());
    QVariant eval(const QString &lua);

    static void pushValue(lua_State *L, QVariant v);
    static QVariant readValue(lua_State *L, int index = 0, QHash<const void *, bool> stack = QHash<const void *, bool>());

    static int pushLibFunc(lua_State *L, const char *libName, const char *funcName);

private:
    lua_State *L;
};
