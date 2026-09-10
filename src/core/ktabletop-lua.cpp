// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "ktabletop-lua.h"
#include "client.h"
#include "lua/c-wrapper.h" // for LuaVM::readValue
#include "lua/lua-binding.h"
#include "network/client-socket.h"
#include "network/user-connection.h"
#include "server.h"

#include <QAbstractSocket>
#include <QStringLiteral>
#include <QTimer>
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
        // FIXME: whatever. I need the code run first
        // if (conn->connId() != connId) {
        //     conn = nullptr;
        // }
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

// args: int connId, string command, string jsonData, int time, int64 timestamp,
//       callback: fun(result: string?, err: string?)
static int requestSocket(lua_State *L)
{
    int nargs = lua_gettop(L);
    if (nargs != 6) {
        return luaL_error(L, "expected 6 arguments, got %d", nargs);
    }
    int connId = luaL_checkinteger(L, 1);
    const char *command = luaL_checkstring(L, 2);
    const char *jsonData = luaL_checkstring(L, 3);
    int time = luaL_checkinteger(L, 4);
    qint64 timestamp = luaL_checkinteger(L, 5);
    luaL_checktype(L, 6, LUA_TFUNCTION);

    auto conn = findConnectionById(L, connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    lua_pushvalue(L, 6);
    int fnRef = luaL_ref(L, LUA_REGISTRYINDEX);

    auto cb = [L = LuaBinding::forState(L)->vm().state(), fnRef](std::error_code err, QByteArray reply) {
        auto binding = LuaBinding::forState(L);
        if (!binding) {
            return;
        }

        int msgh = LuaVM::pushLibFunc(L, "debug", "traceback");

        lua_rawgeti(L, LUA_REGISTRYINDEX, fnRef);
        if (!err) {
            lua_pushnil(L);
        } else {
            lua_pushstring(L, err.message().c_str());
        }
        lua_pushstring(L, reply.constData());

        if (lua_pcall(L, 2, 0, msgh) != LUA_OK) {
            qCritical() << lua_tostring(L, -1);
            lua_pop(L, 1);
        }
        lua_pop(L, 1);

        luaL_unref(L, LUA_REGISTRYINDEX, fnRef);
    };

    int requestId = conn->request(command, jsonData, time, timestamp, cb);

    lua_pushinteger(L, requestId);
    return 1;
}

// args: int connId, int requestId, bool ok, string jsonData
static int replySocket(lua_State *L)
{
    int nargs = lua_gettop(L);
    if (nargs != 4) {
        return luaL_error(L, "expected 4 arguments, got %d", nargs);
    }
    int connId = luaL_checkinteger(L, 1);
    int requestId = luaL_checkinteger(L, 2);
    luaL_checktype(L, 3, LUA_TBOOLEAN);
    bool ok = lua_toboolean(L, 3);
    const char *jsonData = luaL_checkstring(L, 4);

    auto conn = findConnectionById(L, connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    conn->reply(requestId, ok, jsonData);

    return 0;
}

// args: int connId, int requestId
static int cancelRequest(lua_State *L)
{
    int nargs = lua_gettop(L);
    if (nargs != 2) {
        return luaL_error(L, "expected 2 arguments, got %d", nargs);
    }

    int connId = luaL_checkinteger(L, 1);
    int requestId = luaL_checkinteger(L, 2);

    auto conn = findConnectionById(L, connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    conn->cancelRequest(requestId);

    return 0;
}

// void delay(ms, callback: fun())
static int delay(lua_State *L)
{
    auto binding = LuaBinding::forState(L);
    if (!binding) {
        return luaL_error(L, "No LuaBinding found for this Lua VM");
    }

    int nargs = lua_gettop(L);
    if (nargs != 2) {
        return luaL_error(L, "expected 2 arguments (ms, callback), got %d", nargs);
    }

    int ms = luaL_checkinteger(L, 1);
    if (ms < 0) {
        return luaL_error(L, "delay time must be non-negative, got %d", ms);
    }
    luaL_checktype(L, 2, LUA_TFUNCTION);

    // Registry[fnRef] = fn; lua_pop(fn) -- fn is at top of stack
    lua_pushvalue(L, 2);
    int fnRef = luaL_ref(L, LUA_REGISTRYINDEX);

    auto timer = new QTimer(binding);
    timer->setSingleShot(true);
    timer->connect(timer, &QTimer::timeout, [L = binding->vm().state(), timer, fnRef] {
        timer->deleteLater();

        auto binding = LuaBinding::forState(L);
        if (!binding) {
            return;
        }

        int msgh = LuaVM::pushLibFunc(L, "debug", "traceback");

        lua_rawgeti(L, LUA_REGISTRYINDEX, fnRef);
        if (lua_pcall(L, 0, 0, msgh) != LUA_OK) {
            qCritical() << lua_tostring(L, -1);
            lua_pop(L, 1);
        }
        lua_pop(L, 1);

        luaL_unref(L, LUA_REGISTRYINDEX, fnRef);
    });
    timer->start(ms);

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

// client-only: args: string host, int port, callback: fun(err: string?)
static int connectToHost(lua_State *L)
{
    auto binding = LuaBinding::forState(L);
    if (!binding) {
        return luaL_error(L, "No LuaBinding found for this Lua VM");
    }

    if (lua_gettop(L) != 3)
        return luaL_error(L, "expected 3 arguments");
    const char *host = luaL_checkstring(L, 1);
    int port = luaL_checkinteger(L, 2);
    luaL_checktype(L, 3, LUA_TFUNCTION);

    lua_pushvalue(L, 3);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);

    auto *sock = Client::instance()->connection()->socket()->socket();

    auto *timer = new QTimer(binding);
    timer->setSingleShot(true);

    auto ctx = new QObject;

    std::function<void(const char *)> invoke = [ctx, L = binding->vm().state(), ref, timer](const char *err) {
        ctx->deleteLater();
        timer->stop();
        timer->deleteLater();

        int msgh = LuaVM::pushLibFunc(L, "debug", "traceback");
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        if (err) {
            lua_pushstring(L, err);
        } else {
            lua_pushnil(L);
        }

        if (lua_pcall(L, 1, 0, msgh) != LUA_OK) {
            qCritical() << lua_tostring(L, -1);
            lua_pop(L, 1);
        }
        lua_pop(L, 1);
        luaL_unref(L, LUA_REGISTRYINDEX, ref);
    };

    sock->connect(
        sock,
        &QAbstractSocket::connected,
        ctx,
        [invoke] {
            invoke(nullptr);
        },
        Qt::SingleShotConnection);
    sock->connect(
        sock,
        &QAbstractSocket::errorOccurred,
        ctx,
        [invoke, sock](QAbstractSocket::SocketError) {
            invoke(sock->errorString().toUtf8().constData());
        },
        Qt::SingleShotConnection);
    timer->connect(
        timer,
        &QTimer::timeout,
        ctx,
        [invoke] {
            invoke("timeout");
        },
        Qt::SingleShotConnection);
    timer->start(5000);

    sock->connectToHost(QString::fromUtf8(host), static_cast<ushort>(port));
    return 0;
}

// client-only: returns int
static int getConnId(lua_State *L)
{
    lua_pushinteger(L, Client::instance()->connection()->connId());
    return 1;
}

static luaL_Reg commonFuncTable[] = {
    {"notifySocket", notifySocket},
    {"requestSocket", requestSocket},
    {"replySocket", replySocket},
    {"cancelRequest", cancelRequest},

    {"delay", delay},
    {"luaEvent", luaEvent},

    {NULL, NULL},
};

static luaL_Reg clientFuncTable[] = {
    {"connectToHost", connectToHost},
    {"getConnId", getConnId},
    {NULL, NULL},
};

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

extern "C" int luaopen_ktabletop(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, commonFuncTable, 0);

    auto binding = LuaBinding::forState(L);
    if (binding && binding->role() == LuaBinding::Client) {
        luaL_setfuncs(L, clientFuncTable, 0);
    }

    lua_newtable(L); // ktabletop.log
    luaL_setfuncs(L, loggerTable, 0);
    lua_setfield(L, -2, "log");

    lua_setglobal(L, "ktabletop");
    return 0;
}
