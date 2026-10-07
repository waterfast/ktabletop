// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client-lua.h"
#include "catalog.h"
#include "client.h"
#include "lua/async-context.h"
#include "lua/lua-binding.h"
#include "lua/lua-helper.h" // for LuaVM::readValue
#include "network/client-socket.h"
#include "network/crypto-util.h"
#include "network/user-connection.h"
#include "qml/i18n-context.h"

#include <QAbstractSocket>
#include <QTimer>
#include <QUrl>

#include <KLocalizedString>

#include <lua.hpp>

#include <memory>

using namespace KTabletopCrypto;
using namespace Qt::StringLiterals;
using str = const char *;

// args: int connId, string command, string jsonData
static int notifySocket(lua_State *L)
{
    auto [connId, command, jsonData] = LuaVM::readArgs<int, str, str>(L);

    auto *conn = Client::instance()->connection();
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
    auto *conn = Client::instance()->connection();
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

    auto *conn = Client::instance()->connection();
    if (!conn) {
        return luaL_error(L, "cannot find socket of connId %d", connId);
    }

    conn->reply(requestId, ok, jsonData);

    return 0;
}

static int disconnectSocket(lua_State *L)
{
    int connId = luaL_checkinteger(L, 1);

    auto *conn = Client::instance()->connection();
    if (!conn) {
        qWarning() << "[auth] disconnect: cannot find connection" << connId;
        return 0;
    }
    if (auto *tcp = conn->socket()->socket()) {
        tcp->disconnectFromHost();
    }
    return 0;
}

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

        client->startTask(QString::fromUtf8(key), QString::fromUtf8(message), progress, cancelable, std::move(f));
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

static int showToast(lua_State *L)
{
    auto [message] = LuaVM::readArgs<str>(L);
    auto *client = Client::instance();

    Q_EMIT client->showToast(QString::fromUtf8(message));

    return 0;
}

static int showErrorDialog(lua_State *L)
{
    auto [message] = LuaVM::readArgs<str>(L);
    auto *client = Client::instance();

    Q_EMIT client->showErrorDialog(QString::fromUtf8(message));

    return 0;
}

static luaL_Reg clientFuncTable[] = {
    {"notifySocket", notifySocket},
    {"requestSocket", requestSocket},
    {"replySocket", replySocket},
    {"disconnect", disconnectSocket},

    {"connectToHost", connectToHost},

    {"getClientNonce", getClientNonce},
    {"verifyAuthChallenge", verifyAuthChallenge},
    {"acceptServerKey", acceptServerKey},

    {"startTask", startTask},
    {"updateTask", updateTask},
    {"showToast", showToast},
    {"showErrorDialog", showErrorDialog},

    {NULL, NULL},
};

static QString subsLuaArgs(lua_State *L, KLocalizedString msg, int firstArg)
{
    const int n = lua_gettop(L);
    for (int i = firstArg; i <= n; i++) {
        if (lua_isinteger(L, i)) {
            msg = msg.subs(lua_tointeger(L, i));
        } else if (lua_type(L, i) == LUA_TNUMBER) {
            msg = msg.subs(lua_tonumber(L, i));
        } else {
            size_t len = 0;
            const char *s = luaL_tolstring(L, i, &len);
            msg = msg.subs(QString::fromUtf8(s, len));
            lua_pop(L, 1);
        }
    }
    return msg.toString();
}

static QString subsLuaArgs(lua_State *L, QString text, int firstArg)
{
    const int n = lua_gettop(L);
    for (int i = firstArg; i <= n; i++) {
        if (lua_isinteger(L, i)) {
            text = text.arg(lua_tointeger(L, i));
        } else if (lua_type(L, i) == LUA_TNUMBER) {
            text = text.arg(lua_tonumber(L, i));
        } else {
            size_t len = 0;
            const char *s = luaL_tolstring(L, i, &len);
            text = text.arg(QString::fromUtf8(s, len));
            lua_pop(L, 1);
        }
    }
    return text;
}

static int luaI18n(lua_State *L)
{
    const char *text = luaL_checkstring(L, 1);
    auto msg = subsLuaArgs(L, ki18n(text), 2);
    lua_pushstring(L, msg.toUtf8().constData());
    return 1;
}

static int luaI18nc(lua_State *L)
{
    const char *context = luaL_checkstring(L, 1);
    const char *text = luaL_checkstring(L, 2);
    auto msg = subsLuaArgs(L, ki18nc(context, text), 3);
    lua_pushstring(L, msg.toUtf8().constData());
    return 1;
}

static int luaI18np(lua_State *L)
{
    const char *singular = luaL_checkstring(L, 1);
    const char *plural = luaL_checkstring(L, 2);
    auto msg = subsLuaArgs(L, ki18np(singular, plural), 3);
    lua_pushstring(L, msg.toUtf8().constData());
    return 1;
}

static int luaI18ncp(lua_State *L)
{
    const char *context = luaL_checkstring(L, 1);
    const char *singular = luaL_checkstring(L, 2);
    const char *plural = luaL_checkstring(L, 3);
    auto msg = subsLuaArgs(L, ki18ncp(context, singular, plural), 4);
    lua_pushstring(L, msg.toUtf8().constData());
    return 1;
}

static luaL_Reg i18nFuncTable[] = {
    {"i18n", luaI18n},
    {"i18nc", luaI18nc},
    {"i18np", luaI18np},
    {"i18ncp", luaI18ncp},
    {NULL, NULL},
};

static const char *i18nContextMeta = "KTabletop.I18nContext";

struct LuaI18nContext {
    Catalog catalog;
    I18nContext ctx;

    explicit LuaI18nContext(const QUrl &url)
        : catalog(url)
    {
        ctx.setCatalog(&catalog);
    }
};

static LuaI18nContext *checkI18nContext(lua_State *L)
{
    return static_cast<LuaI18nContext *>(luaL_checkudata(L, 1, i18nContextMeta));
}

static int udI18n(lua_State *L)
{
    auto *self = checkI18nContext(L);
    const QString text = QString::fromUtf8(luaL_checkstring(L, 2));
    lua_pushstring(L, subsLuaArgs(L, self->ctx.i18n(text), 3).toUtf8().constData());
    return 1;
}

static int udI18nc(lua_State *L)
{
    auto *self = checkI18nContext(L);
    const QString context = QString::fromUtf8(luaL_checkstring(L, 2));
    const QString text = QString::fromUtf8(luaL_checkstring(L, 3));
    lua_pushstring(L, subsLuaArgs(L, self->ctx.i18nc(context, text), 4).toUtf8().constData());
    return 1;
}

static int udI18np(lua_State *L)
{
    auto *self = checkI18nContext(L);
    const QString singular = QString::fromUtf8(luaL_checkstring(L, 2));
    const QString plural = QString::fromUtf8(luaL_checkstring(L, 3));
    const int n = static_cast<int>(luaL_optinteger(L, 4, 1));
    lua_pushstring(L, subsLuaArgs(L, self->ctx.i18np(singular, plural, n), 4).toUtf8().constData());
    return 1;
}

static int udI18ncp(lua_State *L)
{
    auto *self = checkI18nContext(L);
    const QString context = QString::fromUtf8(luaL_checkstring(L, 2));
    const QString singular = QString::fromUtf8(luaL_checkstring(L, 3));
    const QString plural = QString::fromUtf8(luaL_checkstring(L, 4));
    const int n = static_cast<int>(luaL_optinteger(L, 5, 1));
    lua_pushstring(L, subsLuaArgs(L, self->ctx.i18ncp(context, singular, plural, n), 5).toUtf8().constData());
    return 1;
}

static int udI18nGc(lua_State *L)
{
    auto *self = static_cast<LuaI18nContext *>(luaL_checkudata(L, 1, i18nContextMeta));
    std::destroy_at(self);
    return 0;
}

static luaL_Reg i18nContextFuncTable[] = {
    {"i18n", udI18n},
    {"i18nc", udI18nc},
    {"i18np", udI18np},
    {"i18ncp", udI18ncp},
    {NULL, NULL},
};

static void pushI18nContext(lua_State *L, const QUrl &url)
{
    void *mem = lua_newuserdatauv(L, sizeof(LuaI18nContext), 0);
    std::construct_at(static_cast<LuaI18nContext *>(mem), url);
    if (luaL_newmetatable(L, i18nContextMeta)) {
        lua_pushcfunction(L, udI18nGc);
        lua_setfield(L, -2, "__gc");
        luaL_newlib(L, i18nContextFuncTable);
        lua_setfield(L, -2, "__index");
    }
    lua_setmetatable(L, -2);
}

void injectI18nContext(LuaBinding *binding, const QString &pluginPath)
{
    auto *L = binding->state();
    auto plugin = binding->callKTabletopMethod(u"engine"_s, u"getPlugin"_s, {pluginPath});
    auto ref = plugin.value<LuaRef>().index;
    if (ref == LUA_NOREF) {
        return;
    }
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    luaL_unref(L, LUA_REGISTRYINDEX, ref);
    pushI18nContext(L, QUrl::fromLocalFile(pluginPath));
    lua_setfield(L, -2, "i18nContext");
    lua_pop(L, 1);
}

extern "C" int luaopen_ktabletop_client(lua_State *L)
{
    lua_getglobal(L, "kt");
    lua_getfield(L, -1, "c");
    luaL_setfuncs(L, clientFuncTable, 0);
    luaL_setfuncs(L, i18nFuncTable, 0);
    lua_pop(L, 2);
    return 0;
}
