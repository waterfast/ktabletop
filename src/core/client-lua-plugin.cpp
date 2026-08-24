#include "client-lua-plugin.h"
#include "client.h"
#include "lua/c-wrapper.h"
#include "network/client-socket.h"
#include "network/user-connection.h"

#include <QAbstractSocket>
#include <QTimer>
#include <QVariantMap>
using namespace Qt::Literals::StringLiterals;

#include <lua.hpp>

static int connectToHost(lua_State *L)
{
    if (lua_gettop(L) != 3)
        return luaL_error(L, "expected 3 arguments");
    const char *host = luaL_checkstring(L, 1);
    int port = luaL_checkinteger(L, 2);
    luaL_checktype(L, 3, LUA_TFUNCTION);

    lua_pushvalue(L, 3);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);

    auto *sock = Client::instance()->connection()->socket()->socket();

    auto *timer = new QTimer(Client::instance());
    timer->setSingleShot(true);
    auto done = std::make_shared<bool>(false);

    std::function<void(const char *)> invoke = [L, ref, timer, done](const char *err) {
        if (*done)
            return;
        *done = true;
        timer->stop();
        timer->deleteLater();
        lua_getglobal(L, "debug");
        lua_getfield(L, -1, "traceback");
        lua_replace(L, -2);
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        if (err)
            lua_pushstring(L, err);
        else
            lua_pushnil(L);
        if (lua_pcall(L, 1, 0, -2) != LUA_OK) {
            qCritical() << lua_tostring(L, -1);
            lua_pop(L, 1);
        }
        lua_pop(L, 1);
        luaL_unref(L, LUA_REGISTRYINDEX, ref);
    };

    QObject::connect(
        sock,
        &QAbstractSocket::connected,
        Client::instance(),
        [invoke] {
            invoke(nullptr);
        },
        Qt::SingleShotConnection);
    QObject::connect(
        sock,
        &QAbstractSocket::errorOccurred,
        Client::instance(),
        [invoke, sock](QAbstractSocket::SocketError) {
            invoke(sock->errorString().toUtf8().constData());
        },
        Qt::SingleShotConnection);
    QObject::connect(
        timer,
        &QTimer::timeout,
        Client::instance(),
        [invoke] {
            invoke("timeout");
        },
        Qt::SingleShotConnection);
    timer->start(5000);

    sock->connectToHost(QString::fromUtf8(host), static_cast<ushort>(port));
    return 0;
}

static luaL_Reg clientFuncTable[] = {
    {"connectToHost", connectToHost},
    {NULL, NULL},
};

static int clientPluginSetup(lua_State *L)
{
    if (lua_gettop(L) < 1)
        return luaL_error(L, "at least a ctx param should be provided");
    luaL_checktype(L, 1, LUA_TTABLE);

    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_replace(L, -2);

    lua_getfield(L, 1, "set");
    if (!lua_isfunction(L, -1))
        return luaL_error(L, "ctx.set is not a function");

    lua_pushvalue(L, 1);
    lua_pushliteral(L, "__cpp.client");
    lua_newtable(L);
    luaL_setfuncs(L, clientFuncTable, 0);

    if (lua_pcall(L, 3, 0, -5) != LUA_OK)
        return luaL_error(L, "failed to call ctx:set: %s", lua_tostring(L, -1));

    return 0;
}

QVariantMap ClientLuaPlugin::create()
{
    return {
        {u"name"_s, u"/ktabletop/cpp/clientPlugin"_s},
        {u"ifaces"_s, {u"ktabletop.cpp.client"_s}},
        {u"setup"_s, QVariant::fromValue<lua_CFunction>(clientPluginSetup)},
    };
}
