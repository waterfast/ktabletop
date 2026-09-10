// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

// wrapper classes for Lua and Git2

#include <QHash>
#include <QMutex>
#include <QThread>
#include <QVariant>
#include <lua.hpp>

struct LuaRef {
    int index = LUA_NOREF;
};

class LuaVM
{
public:
    explicit LuaVM();
    LuaVM(LuaVM &) = delete;
    LuaVM(LuaVM &&) = delete;
    ~LuaVM();

    lua_State *state() const;

    void dofile(const QString &path);

    QVariant call(const QString &func_name, QVariantList params = {});

    // call the obj:method(params), obj should at top of stack; stack remains unchanged after call
    QVariant callMethod(const QString &method, QVariantList args = {});

    QVariant eval(const QString &lua);

    static void dumpStack(lua_State *L);
    // call the function with params, function should at top of stack; it will be popped after call
    static QVariant call(lua_State *L, QVariantList params = {});
    static void pushValue(lua_State *L, QVariant v);
    static QVariant readValue(lua_State *L, int index = 0, QHash<const void *, bool> stack = QHash<const void *, bool>());

    static int pushLibFunc(lua_State *L, const char *libName, const char *funcName);

private:
    lua_State *L;
};

Q_DECLARE_METATYPE(LuaRef);
