#include "server-lua-plugin.h"

#include <QVariantMap>
using namespace Qt::Literals::StringLiterals;

#include <lua.hpp>

static luaL_Reg serverFuncTable[] = {
    {NULL, NULL},
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

QVariantMap ServerLuaPlugin::create()
{
    return {
        {u"name"_s, u"/ktabletop/cpp/serverPlugin"_s},
        {u"ifaces"_s, {u"ktabletop.cpp.server"_s}},
        {u"setup"_s, QVariant::fromValue<lua_CFunction>(serverPluginSetup)},
    };
}
