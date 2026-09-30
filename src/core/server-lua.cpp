// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "server-lua.h"
#include "common-lua.h"
#include "db-thread.h"
#include "lua/async-context.h"
#include "lua/c-wrapper.h" // for LuaVM::readValue
#include "lua/lua-binding.h"
#include "network/client-socket.h"
#include "network/crypto-util.h"
#include "network/user-connection.h"
#include "server.h"

#include <QCryptographicHash>
#include <QRandomGenerator>

#include <lua.hpp>

using namespace Qt::Literals::StringLiterals;
using namespace KTabletopCrypto;
using str = const char *;

// args: int connId, string command, string jsonData
static int notifySocket(lua_State *L)
{
    auto [connId, command, jsonData] = LuaVM::readArgs<int, str, str>(L);

    auto *conn = Server::instance()->findConnection(connId);
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
    auto [connId, command, jsonData, time, timestamp, cb] = LuaVM::readArgs<int, str, str, int, qint64, LuaStk<LUA_TFUNCTION>>(L);

    auto *binding = LuaBinding::forState(L);
    auto *conn = Server::instance()->findConnection(connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    lua_pushvalue(L, cb.index);
    int fnRef = luaL_ref(L, LUA_REGISTRYINDEX);

    auto *ctx = new AsyncContext(binding, fnRef);
    int requestId = conn->request(command, jsonData, time, timestamp, [ctx](std::error_code err, QByteArray reply) {
        ctx->complete(err, reply);
    });
    QObject::connect(ctx, &AsyncContext::cancelled, conn, [conn, requestId] {
        conn->cancelRequest(requestId);
    });

    return LuaBinding::pushAsyncCancelToken(L, ctx);
}

// args: int connId, int requestId, bool ok, string jsonData
static int replySocket(lua_State *L)
{
    auto [connId, requestId, ok, jsonData] = LuaVM::readArgs<int, int, bool, str>(L);

    auto *conn = Server::instance()->findConnection(connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    conn->reply(requestId, ok, jsonData);

    return 0;
}

static int disconnectSocket(lua_State *L)
{
    int connId = luaL_checkinteger(L, 1);

    auto *conn = Server::instance()->findConnection(connId);
    if (!conn) {
        qWarning() << "[auth] disconnect: cannot find connection" << connId;
        return 0;
    }
    if (auto *tcp = conn->socket()->socket()) {
        tcp->disconnectFromHost();
    }
    return 0;
}

// TODO: todoo.... just testing now
static int startGame(lua_State *L)
{
    int roomId = luaL_checkinteger(L, 1);
    QVariantMap data = LuaVM::readValue(L, 2).toMap();
    Server::instance()->startGameRoom(roomId, data);
    return 0;
}

static int getServerPublicKey(lua_State *L)
{
    lua_pushstring(L, Server::instance()->authPublicKey().toUtf8().constData());
    return 1;
}

static int makeAuthChallenge(lua_State *L)
{
    auto [connId, nonceBase64] = LuaVM::readArgs<int, str>(L);
    const QByteArray nonce = QByteArray::fromBase64(nonceBase64);

    auto *server = Server::instance();
    auto *conn = server->findConnection(connId);
    if (!conn) {
        return luaL_error(L, "cannot find connection of connId %d", connId);
    }

    EVP_PKEY *ephemeral = generateX25519KeyPairs();
    if (!ephemeral) {
        return luaL_error(L, "failed to generate X25519 key pair");
    }

    const QByteArray serverPub = x25519RawPublicKey(ephemeral);
    conn->setAuthEphemeralKey(ephemeral);

    const QByteArray transcript = QByteArrayLiteral("ktabletop-handshake-v1") + nonce + serverPub;
    const QByteArray sig = ed25519Sign(server->authPrivateKey(), transcript);

    LuaVM::pushValue(L,
                     QVariantMap{
                         {u"idPub"_s, server->authPublicKey()},
                         {u"serverPub"_s, QString::fromLatin1(serverPub.toBase64())},
                         {u"sig"_s, QString::fromLatin1(sig.toBase64())},
                     });
    return 1;
}

static int acceptClientKey(lua_State *L)
{
    auto [connId, keyBase64] = LuaVM::readArgs<int, str>(L);
    const QByteArray clientPub = QByteArray::fromBase64(keyBase64);

    auto *conn = Server::instance()->findConnection(connId);
    if (!conn) {
        lua_pushboolean(L, false);
        return 1;
    }

    EVP_PKEY *ephemeral = conn->takeAuthEphemeralKey();
    if (!ephemeral) {
        lua_pushboolean(L, false);
        return 1;
    }

    const QByteArray shared = x25519DeriveShared(ephemeral, clientPub);
    EVP_PKEY_free(ephemeral);
    if (shared.isEmpty()) {
        lua_pushboolean(L, false);
        return 1;
    }

    const QByteArray key = hkdfSha256(shared, QByteArray(), QByteArrayLiteral("ktabletop-handshake-v1"), 32);
    conn->setPeerEphPublicKey(clientPub);
    conn->enableEncryption(key);

    lua_pushboolean(L, true);
    return 1;
}

static int findUserByUsername(lua_State *L)
{
    auto [username] = LuaVM::readArgs<str>(L);

    const auto [err, rows] =
        Server::instance()->usersDb()->execQuerySync(u"SELECT id, username, displayName, password, salt, banned FROM userInfo WHERE username = ?"_s,
                                                     QString::fromUtf8(username));

    if (err.isValid()) {
        qWarning().noquote() << "findUserByUsername failed:" << err.text();
        lua_pushboolean(L, false);
        lua_pushstring(L, qPrintable(err.text()));
        return 2;
    }
    if (rows.isEmpty()) {
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }

    const auto &row = rows.first();
    lua_pushboolean(L, true);
    LuaVM::pushValue(L,
                     QVariantMap{
                         {u"id"_s, row.at(0)},
                         {u"username"_s, row.at(1)},
                         {u"displayName"_s, row.at(2)},
                         {u"password"_s, row.at(3)},
                         {u"salt"_s, row.at(4)},
                         {u"banned"_s, row.at(5)},
                     });
    return 2;
}

static int registerUser(lua_State *L)
{
    auto [username, password] = LuaVM::readArgs<str, str>(L);

    auto saltGen = QRandomGenerator::securelySeeded();
    const QByteArray salt = QByteArray::number(saltGen(), 16);

    QByteArray pw(password);
    pw.append(salt);
    const QByteArray passwordHash = QCryptographicHash::hash(pw, QCryptographicHash::Sha256).toHex();

    const auto result =
        Server::instance()->usersDb()->execQuerySync(u"INSERT INTO userInfo (username, displayName, password, salt, banned) VALUES (?, ?, ?, ?, 0)"_s,
                                                     QString::fromUtf8(username),
                                                     QString::fromUtf8(username),
                                                     QString::fromLatin1(passwordHash),
                                                     QString::fromLatin1(salt));

    if (result.first.isValid()) {
        qWarning().noquote() << "registerUser failed:" << result.first.text();
        lua_pushboolean(L, false);
        lua_pushstring(L, qPrintable(result.first.text()));
        return 2;
    }
    lua_pushboolean(L, true);
    return 1;
}

static luaL_Reg serverFuncTable[] = {
    {"notifySocket", notifySocket},
    {"requestSocket", requestSocket},
    {"replySocket", replySocket},
    {"disconnect", disconnectSocket},

    {"startGame", startGame},

    {"getServerPublicKey", getServerPublicKey},
    {"makeAuthChallenge", makeAuthChallenge},
    {"acceptClientKey", acceptClientKey},

    {"findUserByUsername", findUserByUsername},
    {"registerUser", registerUser},

    {NULL, NULL},
};

extern "C" int luaopen_ktabletop_server(lua_State *L)
{
    lua_getglobal(L, "ktabletop");
    luaL_setfuncs(L, serverFuncTable, 0);
    lua_pop(L, 1);
    return 0;
}
