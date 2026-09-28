// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "ktabletop-lua.h"
#include "async-context.h"
#include "client.h"
#include "db-thread.h"
#include "lua/c-wrapper.h" // for LuaVM::readValue
#include "lua/lua-binding.h"
#include "network/client-socket.h"
#include "network/crypto-util.h"
#include "network/user-connection.h"
#include "server.h"

#include <QAbstractSocket>
#include <QCryptographicHash>
#include <QRandomGenerator>
#include <QTimer>

#include <lua.hpp>

using namespace Qt::Literals::StringLiterals;
using namespace KTabletopCrypto;
using str = const char *;

static UserConnection *findConnectionById(lua_State *L, int connId)
{
    auto *binding = LuaBinding::forState(L);
    if (!binding) {
        return nullptr;
    }
    auto role = binding->role();

    UserConnection *conn = nullptr;
    if (role == LuaBinding::Server || role == LuaBinding::GameThread) {
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
    auto [connId, command, jsonData] = LuaVM::readArgs<int, str, str>(L);

    auto *conn = findConnectionById(L, connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    conn->notify(command, jsonData);

    return 0;
}

static int pushAsyncCancelToken(lua_State *L, AsyncContext *ctx)
{
    // ctx is certainly alive when calling this function from Lua
    // because this will only be triggered by async.cancel,
    // and if ctx->complete has been called,
    // corresponding awaitable should have done and removed from calling chain
    constexpr auto f = [](lua_State *L) {
        auto *ctx = static_cast<AsyncContext *>(lua_touserdata(L, lua_upvalueindex(1)));
        ctx->cancel();
        return 0;
    };

    lua_pushlightuserdata(L, ctx);
    lua_pushcclosure(L, f, 1);
    return 1;
}

// args: int connId, string command, string jsonData, int time, int64 timestamp,
//       callback: fun(result: string?, err: string?)
static int requestSocket(lua_State *L)
{
    auto [connId, command, jsonData, time, timestamp, cb] = LuaVM::readArgs<int, str, str, int, qint64, LuaStk<LUA_TFUNCTION>>(L);

    auto *binding = LuaBinding::forState(L);
    auto *conn = findConnectionById(L, connId);
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

    return pushAsyncCancelToken(L, ctx);
}

// args: int connId, int requestId, bool ok, string jsonData
static int replySocket(lua_State *L)
{
    auto [connId, requestId, ok, jsonData] = LuaVM::readArgs<int, int, bool, str>(L);

    auto *conn = findConnectionById(L, connId);
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    conn->reply(requestId, ok, jsonData);

    return 0;
}

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

    return pushAsyncCancelToken(L, ctx);
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

// client-only: args: string host, int port, callback: fun(err: string?)
static int connectToHost(lua_State *L)
{
    auto [host, port, cb] = LuaVM::readArgs<str, int, LuaStk<LUA_TFUNCTION>>(L);
    auto *binding = LuaBinding::forState(L);
    if (!binding) {
        return luaL_error(L, "No LuaBinding found for this Lua VM");
    }

    lua_pushvalue(L, cb.index);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);

    auto *sock = Client::instance()->connection()->socket()->socket();

    auto *ctx = new AsyncContext(binding, ref);
    auto *timer = new QTimer(ctx);
    timer->setSingleShot(true);

    sock->connect(sock, &QAbstractSocket::connected, ctx, &AsyncContext::completeVoid);
    sock->connect(sock, &QAbstractSocket::errorOccurred, ctx, [ctx](QAbstractSocket::SocketError) {
        ctx->complete(std::make_error_code(std::errc::not_connected));
    });
    timer->connect(timer, &QTimer::timeout, ctx, [ctx] {
        ctx->complete(std::make_error_code(std::errc::timed_out));
    });
    timer->start(5000);

    sock->connectToHost(QString::fromUtf8(host), static_cast<ushort>(port));
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

static int disconnectSocket(lua_State *L)
{
    int connId = luaL_checkinteger(L, 1);

    auto *conn = findConnectionById(L, connId);
    if (!conn) {
        qWarning() << "[auth] disconnect: cannot find connection" << connId;
        return 0;
    }
    if (auto *tcp = conn->socket()->socket()) {
        tcp->disconnectFromHost();
    }
    return 0;
}

static int getClientNonce(lua_State *L)
{
    const QByteArray nonce = generateNonce();
    Client::instance()->connection()->setAuthNonce(nonce);

    const QByteArray b64 = nonce.toBase64();
    lua_pushlstring(L, b64.constData(), b64.size());
    return 1;
}

static int verifyAuthChallenge(lua_State *L)
{
    auto [idPub, serverPubBase64, sigBase64] = LuaVM::readArgs<str, str, str>(L);
    const QByteArray serverPub = QByteArray::fromBase64(serverPubBase64);
    const QByteArray sig = QByteArray::fromBase64(sigBase64);

    auto *conn = Client::instance()->connection();
    const QByteArray nonce = conn->authNonce();

    EVP_PKEY *idKey = loadPublicKeyPem(idPub);
    if (!idKey) {
        lua_pushstring(L, "");
        return 1;
    }

    const QByteArray transcript = QByteArrayLiteral("ktabletop-handshake-v1") + nonce + serverPub;
    const bool verified = ed25519Verify(idKey, transcript, sig);
    EVP_PKEY_free(idKey);

    if (!verified) {
        lua_pushstring(L, "");
        return 1;
    }

    EVP_PKEY *ephemeral = generateX25519KeyPairs();
    if (!ephemeral) {
        lua_pushstring(L, "");
        return 1;
    }

    const QByteArray clientPub = x25519RawPublicKey(ephemeral);
    conn->setAuthEphemeralKey(ephemeral);
    conn->setPeerEphPublicKey(serverPub);

    const QByteArray b64 = clientPub.toBase64();
    lua_pushlstring(L, b64.constData(), b64.size());
    return 1;
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

static int acceptServerKey(lua_State *L)
{
    auto *conn = Client::instance()->connection();
    if (!conn) {
        lua_pushboolean(L, false);
        return 1;
    }

    EVP_PKEY *ephemeral = conn->takeAuthEphemeralKey();
    const QByteArray peerKey = conn->peerEphPublicKey();
    if (!ephemeral || peerKey.isEmpty()) {
        EVP_PKEY_free(ephemeral);
        lua_pushboolean(L, false);
        return 1;
    }

    const QByteArray shared = x25519DeriveShared(ephemeral, peerKey);
    EVP_PKEY_free(ephemeral);
    if (shared.isEmpty()) {
        lua_pushboolean(L, false);
        return 1;
    }

    const QByteArray key = hkdfSha256(shared, QByteArray(), QByteArrayLiteral("ktabletop-handshake-v1"), 32);
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

static int sha256(lua_State *L)
{
    auto [data] = LuaVM::readArgs<str>(L);
    const QByteArray hash = QCryptographicHash::hash(data, QCryptographicHash::Sha256);
    const QByteArray hex = hash.toHex();
    lua_pushlstring(L, hex.constData(), hex.size());
    return 1;
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

static int startTask(lua_State *L)
{
    const char *key, *message;
    int progress;
    bool cancelable = false;
    LuaStk<LUA_TFUNCTION> cb{0};
    int nargs = lua_gettop(L);
    auto *client = Client::instance();

    if (nargs == 3) {
        std::tie(key, message, progress) = LuaVM::readArgs<str, str, int>(L);
        client->startTask(QString::fromUtf8(key), QString::fromUtf8(message), progress);
    } else if (nargs == 5) {
        std::tie(key, message, progress, cancelable, cb) = LuaVM::readArgs<str, str, int, bool, decltype(cb)>(L);

        lua_pushvalue(L, cb.index);
        int fnRef = luaL_ref(L, LUA_REGISTRYINDEX);
        // FIXME: mind lifecycle of L (L may be a coroutine.)
        auto f = [L, fnRef, _ = LuaRefRAII{L, fnRef}] {
            lua_rawgeti(L, LUA_REGISTRYINDEX, fnRef);
            LuaVM::call(L);
        };

        client->startTask(QString::fromUtf8(key), QString::fromUtf8(message), progress, cancelable, f);
    } else {
        return luaL_error(L, "expected 3 or 5 arguments, got %d", nargs);
    }

    return 0;
}

static int updateTask(lua_State *L)
{
    int nargs = lua_gettop(L);
    auto *client = Client::instance();

    if (nargs == 2) {
        auto [key, progress] = LuaVM::readArgs<str, int>(L);
        client->updateTask(QString::fromUtf8(key), progress);
    } else if (nargs == 3) {
        auto [key, progress, message] = LuaVM::readArgs<str, int, str>(L);
        client->updateTask(QString::fromUtf8(key), progress, QString::fromUtf8(message));
    } else {
        return luaL_error(L, "expected 2 or 3 arguments, got %d", nargs);
    }

    return 0;
}

static luaL_Reg commonFuncTable[] = {
    {"notifySocket", notifySocket},
    {"requestSocket", requestSocket},
    {"replySocket", replySocket},

    {"delay", delay},
    {"luaEvent", luaEvent},

    {"disconnect", disconnectSocket},

    {"sha256", sha256},

    {NULL, NULL},
};

static luaL_Reg clientFuncTable[] = {
    {"connectToHost", connectToHost},

    {"getClientNonce", getClientNonce},
    {"verifyAuthChallenge", verifyAuthChallenge},
    {"acceptServerKey", acceptServerKey},

    {"startTask", startTask},
    {"updateTask", updateTask},

    {NULL, NULL},
};

static luaL_Reg serverFuncTable[] = {
    {"startGame", startGame},

    {"getServerPublicKey", getServerPublicKey},
    {"makeAuthChallenge", makeAuthChallenge},
    {"acceptClientKey", acceptClientKey},

    {"findUserByUsername", findUserByUsername},
    {"registerUser", registerUser},

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

// --------------------------------------------
//   ktabletop.log: logging functions
// --------------------------------------------

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

    auto *binding = LuaBinding::forState(L);
    if (binding && binding->role() == LuaBinding::Client) {
        luaL_setfuncs(L, clientFuncTable, 0);
    } else if (binding && binding->role() == LuaBinding::Server) {
        luaL_setfuncs(L, serverFuncTable, 0);
    }

    lua_newtable(L); // ktabletop.log
    luaL_setfuncs(L, loggerTable, 0);
    lua_setfield(L, -2, "log");

    lua_setglobal(L, "ktabletop");
    return 0;
}
