#include "common-lua-plugin.h"
#include "client.h"
#include "lua/c-wrapper.h" // for LuaVM::readValue
#include "lua/lua-binding.h"
#include "network/user-connection.h"
#include "server.h"

#include <QStringLiteral>
using namespace Qt::Literals::StringLiterals;

#include <lua.hpp>

static UserConnection *findConnectionById(lua_State *L, int connId)
{
    auto binding = LuaBinding::forState(L);
    if (!binding) {
        return nullptr;
    }
    auto role = binding->role();

    UserConnection *conn = nullptr;
    if (role == LuaBinding::Server) {
        conn = Server::instance()->findConnection(connId);
    } else {
        conn = Client::instance()->connection();
        // should not allow mismatch connId
        if (conn->connId() != connId) {
            conn = nullptr;
        }
    }

    return conn;
}

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

    auto conn = findConnectionById(L, connId);
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

    auto conn = findConnectionById(L, connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    conn->request(command, jsonData, time, timestamp);

    return 0;
}

// args: int connId, int requestId, string jsonData
static int replySocket(lua_State *L)
{
    int nargs = lua_gettop(L);
    if (nargs != 3) {
        return luaL_error(L, "expected 3 arguments, got %d", nargs);
    }
    int connId = luaL_checkinteger(L, 1);
    int requestId = luaL_checkinteger(L, 2);
    const char *jsonData = luaL_checkstring(L, 3);

    auto conn = findConnectionById(L, connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    conn->reply(requestId, jsonData);

    return 0;
}

// args: string type, var data
static int luaEvent(lua_State *L)
{
    auto binding = LuaBinding::forState(L);
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

static luaL_Reg commonFuncTable[] = {
    {"notifySocket", notifySocket},
    {"requestSocket", requestSocket},
    {"replySocket", replySocket},

    {"luaEvent", luaEvent},

    {NULL, NULL},
};

static int commonPluginSetup(lua_State *L)
{
    int nargs = lua_gettop(L);
    if (nargs < 1) {
        return luaL_error(L, "at least a ctx param should be provided");
    }
    luaL_checktype(L, 1, LUA_TTABLE);

    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_replace(L, -2);

    // ctx:set("__cpp.common", functable) ctx should be the first arg
    lua_getfield(L, 1, "set");
    if (!lua_isfunction(L, -1)) {
        return luaL_error(L, "ctx.set is not a function");
    }

    lua_pushvalue(L, 1); // push ctx to stack top
    lua_pushliteral(L, "__cpp.common");
    lua_newtable(L);
    luaL_setfuncs(L, commonFuncTable, 0);

    if (lua_pcall(L, 3, 0, -5) != LUA_OK) {
        return luaL_error(L, "failed to call ctx:set: %s", lua_tostring(L, -1));
    }

    return 0;
}

QVariantMap CommonLuaPlugin::create()
{
    return {
        {u"name"_s, u"/ktabletop/cpp/commonPlugin"_s},
        {u"ifaces"_s, {u"ktabletop.cpp.common"_s}},
        {u"setup"_s, QVariant::fromValue<lua_CFunction>(commonPluginSetup)},
    };
}
