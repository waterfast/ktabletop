// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua-binding.h"
#include "c-wrapper.h"

#include <QDir>
#include <QString>

#include <QStringLiteral>
using namespace Qt::Literals::StringLiterals;

#include "server.h"
#include "user-connection.h"
#include <lua.hpp>

// args: int connId, string command, string jsonData
static int notifySocket(lua_State *L)
{
    int nargs = lua_gettop(L);
    if (nargs != 3) {
        return luaL_error(L, "expected 3 arguments, got %d", nargs);
    }
    int connId = luaL_checkinteger(L, 1);
    const char *command = luaL_checkstring(L, 2);
    const char *jsonData = luaL_checkstring(L, 3);

    auto conn = Server::instance()->findConnection(connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    conn->notify(command, jsonData);

    return 0;
}

// args: int connId, string command, string jsonData, int time, int64 timestamp
static int requestSocket(lua_State *L)
{
    int nargs = lua_gettop(L);
    if (nargs != 5) {
        return luaL_error(L, "expected 5 arguments, got %d", nargs);
    }
    int connId = luaL_checkinteger(L, 1);
    const char *command = luaL_checkstring(L, 2);
    const char *jsonData = luaL_checkstring(L, 3);
    int time = luaL_checkinteger(L, 4);
    qint64 timestamp = luaL_checkinteger(L, 5);

    auto conn = Server::instance()->findConnection(connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    conn->request(command, jsonData, time, timestamp);

    return 0;
}

// args: int connId, string jsonData
static int replySocket(lua_State *L)
{
    int nargs = lua_gettop(L);
    if (nargs != 2) {
        return luaL_error(L, "expected 2 arguments, got %d", nargs);
    }
    int connId = luaL_checkinteger(L, 1);
    const char *jsonData = luaL_checkstring(L, 2);

    auto conn = Server::instance()->findConnection(connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    conn->reply(jsonData);

    return 0;
}

static luaL_Reg serverFuncTable[] = {
    {"notifySocket", notifySocket},
    {"requestSocket", requestSocket},
    {"replySocket", replySocket},
    {NULL, NULL}, //
};

static int serverPluginSetup(lua_State *L)
{
    int nargs = lua_gettop(L);
    if (nargs < 1) {
        return luaL_error(L, "at least a ctx param should be provided");
    }
    luaL_checktype(L, 1, LUA_TTABLE);

    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_replace(L, -2);

    // ctx:set("__cpp.server", functable) ctx should be the first arg
    lua_getfield(L, 1, "set");
    if (!lua_isfunction(L, -1)) {
        return luaL_error(L, "ctx.set is not a function");
    }

    lua_pushvalue(L, 1); // push ctx to stack top
    lua_pushliteral(L, "__cpp.server");
    lua_newtable(L);
    luaL_setfuncs(L, serverFuncTable, 0);

    if (lua_pcall(L, 3, 0, -5) != LUA_OK) {
        return luaL_error(L, "failed to call ctx:set: %s", lua_tostring(L, -1));
    }

    return 0;
}

static QVariantMap serverPlugin = {
    {u"name"_s, u"/ktabletop/cpp/serverPlugin"_s},
    {u"ifaces"_s, {u"ktabletop.cpp.server"_s}},
    {u"setup"_s, QVariant::fromValue<lua_CFunction>(serverPluginSetup)},
};

LuaBinding::LuaBinding(QObject *parent, Role role)
    : QObject(parent)
{
    L = new LuaVM;

    QDir::setCurrent(u"scripts"_s);
    if (role == Server) {
        L->dofile(u"ktabletop/server-entry.lua"_s);
        loadPlugin(serverPlugin);
    } else {
        L->dofile(u"ktabletop/client-entry.lua"_s);
    }
    QDir::setCurrent(u".."_s);
}

LuaBinding::~LuaBinding()
{
    delete L;
}

void LuaBinding::emit(const QString &type, const QVariantMap &payload)
{
    L->call(u"Emit"_s, {type, payload});
}

void LuaBinding::loadPlugin(const QVariantMap &plugin)
{
    L->call(u"LoadPlugin"_s, {plugin});
}

LuaVM &LuaBinding::vm()
{
    return *L;
}
