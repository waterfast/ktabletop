// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "common-lua.h"
#include "lua/async-context.h"
#include "lua/lua-binding.h"
#include "lua/lua-helper.h" // for LuaVM::readValue

#include <QCryptographicHash>
#include <QTimer>

#include <lua.hpp>

using namespace Qt::Literals::StringLiterals;
using str = const char *;

// void delay(ms, callback)
static int delay(lua_State *L)
{
    auto [ms, cb] = LuaVM::readArgs<int, LuaStk<LUA_TFUNCTION>>(L);
    auto *binding = LuaBinding::forState(L);
    if (!binding) {
        return luaL_error(L, "No LuaBinding found for this Lua VM");
    }

    lua_pushvalue(L, cb.index);
    int fnRef = luaL_ref(L, LUA_REGISTRYINDEX);

    auto *ctx = new AsyncContext(binding, fnRef);
    auto *timer = new QTimer(ctx);
    timer->setSingleShot(true);
    timer->connect(timer, &QTimer::timeout, ctx, &AsyncContext::completeVoid);
    timer->start(ms);

    return LuaBinding::pushAsyncCancelToken(L, ctx);
}

// args: string type, var data
static int luaEvent(lua_State *L)
{
    auto *binding = LuaBinding::forState(L);
    if (!binding) {
        return luaL_error(L, "No LuaBinding found for this Lua VM");
    }

    int nargs = lua_gettop(L);
    if (nargs != 2) {
        return luaL_error(L, "expected 2 arguments, got %d", nargs);
    }

    const char *type = luaL_checkstring(L, 1);
    QVariant payload = LuaVM::readValue(L, 2);
    binding->triggerLuaEvent(QString::fromUtf8(type), payload);

    return 0;
}

static int sha256(lua_State *L)
{
    auto [data] = LuaVM::readArgs<str>(L);
    const QByteArray hash = QCryptographicHash::hash(data, QCryptographicHash::Sha256);
    const QByteArray hex = hash.toHex();
    lua_pushlstring(L, hex.constData(), hex.size());
    return 1;
}

static luaL_Reg commonFuncTable[] = {
    {"delay", delay},
    {"luaEvent", luaEvent},

    {"sha256", sha256},

    {NULL, NULL},
};

static int getPluginRoot(lua_State *L)
{
    auto *binding = LuaBinding::forState(L);
    if (!binding) {
        lua_pushnil(L);
        return 1;
    }

    const auto &root = binding->currentPluginRoot();
    if (root.isEmpty()) {
        lua_pushnil(L);
        return 1;
    }

    lua_pushstring(L, root.toUtf8().constData());
    return 1;
}

static luaL_Reg pluginHelperFuncTable[] = {
    {"getPluginRoot", getPluginRoot},

    {NULL, NULL},
};

// --------------------------------------------
//   ktabletop.log: logging functions
// --------------------------------------------

// Something like Lua `print` function, that is,
// read varargs and output everything in order, separated by '\t'.
// Non-string values are converted via `tostring (luaL_tolstring) first.
static QString collectLogArgs(lua_State *L)
{
    const int n = lua_gettop(L);
    QString result;
    for (int i = 1; i <= n; i++) {
        size_t len = 0;
        const char *s = luaL_tolstring(L, i, &len);
        if (i > 1) {
            result += QLatin1Char('\t');
        }
        result += QString::fromUtf8(s, static_cast<int>(len));
        lua_pop(L, 1);
    }
    return result;
}

static int loggerInfo(lua_State *L)
{
    qInfo().noquote() << collectLogArgs(L);
    return 0;
}

static int loggerWarn(lua_State *L)
{
    qWarning().noquote() << collectLogArgs(L);
    return 0;
}

static int loggerDebug(lua_State *L)
{
    qDebug().noquote() << collectLogArgs(L);
    return 0;
}

static int loggerCritical(lua_State *L)
{
    qCritical().noquote() << collectLogArgs(L);
    return 0;
}

static luaL_Reg loggerTable[] = {
    {"info", loggerInfo},
    {"warn", loggerWarn},
    {"debug", loggerDebug},
    {"critical", loggerCritical},
    {NULL, NULL},
};

extern "C" int luaopen_ktabletop_common(lua_State *L)
{
    lua_newtable(L);

    lua_newtable(L); // kt.c
    luaL_setfuncs(L, commonFuncTable, 0);
    luaL_setfuncs(L, pluginHelperFuncTable, 0);
    lua_setfield(L, -2, "c");

    lua_newtable(L); // kt.log
    luaL_setfuncs(L, loggerTable, 0);
    lua_setfield(L, -2, "log");

    lua_setglobal(L, "kt");
    return 0;
}
