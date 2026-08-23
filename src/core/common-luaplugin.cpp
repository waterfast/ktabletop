#include "common-lua-plugin.h"
#include "lua/c-wrapper.h" // for LuaVM::readValue
#include "lua/lua-binding.h"

#include <QStringLiteral>
using namespace Qt::Literals::StringLiterals;

#include <lua.hpp>

// args: string type, var data
static int luaEvent(lua_State *L)
{
    int nargs = lua_gettop(L);
    if (nargs != 2) {
        return luaL_error(L, "expected 2 arguments, got %d", nargs);
    }

    auto binding = bindingInstances.value(L);
    if (!binding) {
        return luaL_error(L, "No LuaBinding found for this Lua VM");
    }

    const char *type = luaL_checkstring(L, 1);
    QVariant payload = LuaVM::readValue(L, 2);
    binding->triggerLuaEvent(QString::fromUtf8(type), payload);

    return 0;
}

static luaL_Reg commonFuncTable[] = {
    {"luaEvent", luaEvent},
    {NULL, NULL}, //
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

    // ctx:set("__cpp.server", functable) ctx should be the first arg
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