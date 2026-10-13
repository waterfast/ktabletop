// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "server.h"
#include "core/lua/lua-binding.h"
#include "core/luabinding/common-lua.h"
#include "core/luabinding/server-lua.h"
#include "core/network/client-socket.h"
#include "core/network/crypto-util.h"
#include "core/network/server-socket.h"
#include "core/network/user-connection.h"
#include "core/packman.h"
#include "db-thread.h"
#include "game-thread.h"
#include "stdin-adapter.h"
#include "util.h"

#include <QJsonDocument>
#include <QJsonValue>
#include <QSettings>

#include <QFile>

using namespace Qt::Literals::StringLiterals;
using namespace KTabletopCrypto;
using namespace KTabletopUtils;

static Server *serverInstance = nullptr;

Server *Server::instance()
{
    if (!serverInstance) {
        serverInstance = new Server;
    }
    return serverInstance;
}

bool Server::initialized()
{
    return serverInstance != nullptr;
}

void Server::destroy()
{
    delete serverInstance;
    serverInstance = nullptr;
}

Server::Server(QObject *parent)
    : QObject(parent)
{
    m_dataPath = u"%1/server"_s.arg(KTabletopUtils::runtimeDataDir());

    L = new LuaBinding(this, LuaBinding::Server);
    connect(L, &LuaBinding::luaWarning, this, &Server::luaWarning);
    luaopen_ktabletop_common(L->state());
    luaopen_ktabletop_server(L->state());
    L->setRuntimePaths(PackMan::instance()->listPluginPaths());

    initAuthKeys();

    initConfig();

    server = new ServerSocket(this);
    connect(server, &ServerSocket::newConnection, this, &Server::processNewConnection);

    initUsersDb();

    m_shell = new StdinAdapter(this);
}

void Server::initUsersDb()
{
    delete m_usersDb;
    m_usersDb = new DbThread(this, u"usersDb"_s, u"%1/users.db"_s.arg(m_dataPath));
    // NOTE: DO NOT contain any ';' in comments of .sql file
    auto usersDbSchema = readWholeFile(u":/sql/users-init.sql"_s);
    m_usersDb->execMultiSql(usersDbSchema);
}

void Server::initConfig()
{
    delete m_config;
    m_config = new QSettings(u"%1/config.ini"_s.arg(m_dataPath), QSettings::IniFormat, this);
}

void Server::setDataPath(const QString &path)
{
    if (m_dataPath == path) {
        return;
    }

    m_dataPath = path;
    initAuthKeys();
    initUsersDb();
    initConfig();
}

QSettings *Server::config() const
{
    return m_config;
}

void Server::reloadConfig()
{
    if (m_config) {
        m_config->sync();
    }
}

Server::~Server()
{
    EVP_PKEY_free(m_authPrivateKey);
    serverInstance = nullptr;
}

void Server::initAuthKeys()
{
    EVP_PKEY_free(m_authPrivateKey);
    m_authPrivateKey = nullptr;

    const QString privPath = u"%1/ed25519.key"_s.arg(m_dataPath);
    const QString pubPath = u"%1/ed25519.key.pub"_s.arg(m_dataPath);

    if (!QFile::exists(privPath) || !QFile::exists(pubPath)) {
        EVP_PKEY *pkey = generateEd25519KeyPairs();
        if (!pkey) {
            qFatal("Failed to generate Ed25519 key pair");
        }
        if (!writeKeyPair(privPath, pubPath, pkey)) {
            EVP_PKEY_free(pkey);
            qFatal("Failed to write Ed25519 key pair to %s", qPrintable(m_dataPath));
        }
        EVP_PKEY_free(pkey);
        qInfo() << "Generated Ed25519 key pair at" << privPath;
    }

    m_authPrivateKey = loadPrivateKey(privPath);
    if (!m_authPrivateKey) {
        qFatal("Failed to load private key %s", qPrintable(privPath));
    }

    m_authPublicKey = readWholeFile(pubPath);
    if (m_authPublicKey.isEmpty()) {
        qFatal("Failed to load public key %s", qPrintable(pubPath));
    }
}

QString Server::authPublicKey() const
{
    return m_authPublicKey;
}

EVP_PKEY *Server::authPrivateKey() const
{
    return m_authPrivateKey;
}

bool Server::listen(const QHostAddress &address, ushort port)
{
    bool ret = server->listen(address, port);
    if (ret) {
        qInfo("Server is listening on port %d", port);
        m_shell->start();
    }
    return ret;
}

UserConnection *Server::findConnection(int connId) const
{
    const QMutexLocker locker(&m_connectionsLock);
    return connections.value(connId);
}

LuaBinding *Server::luaBinding() const
{
    return L;
}

GameThread *Server::createGameThread()
{
    auto *thread = new GameThread(this);
    gameThreads.insert(thread->id(), thread);
    return thread;
}

GameThread *Server::getGameThread(int id) const
{
    return gameThreads.value(id);
}

void Server::removeGameThread(int id)
{
    if (auto *thread = gameThreads.take(id)) {
        thread->deleteLater();
    }
}

GameThread *Server::getAvailableGameThread()
{
    for (auto *thread : gameThreads) {
        if (!thread->isFull()) {
            return thread;
        }
    }
    return createGameThread();
}

void Server::startGameRoom(int roomId, const QVariantMap &data)
{
    auto *thread = getAvailableGameThread();
    thread->addRoom(roomId);
    thread->pushRequest(roomId, 0, u"newroom"_s, data);
}

void Server::removeGameRoom(int threadId, int roomId)
{
    auto *thr = gameThreads.value(threadId);
    if (thr) {
        thr->removeRoom(roomId);
    }
}

void Server::dispatchLuaEvent(const QString &type, const QVariant &data)
{
    L->callKTabletopMethod(u"server"_s, u"dispatchLuaEvent"_s, {type, data});
}

DbThread *Server::usersDb() const
{
    return m_usersDb;
}

StdinAdapter *Server::shell() const
{
    return m_shell;
}

void Server::processNewConnection(ClientSocket *client)
{
    auto *socket = client->socket();
    auto addr = QString(u"[%1]:%2"_s).arg(socket->peerAddress().toString()).arg(socket->peerPort());

    auto *conn = new UserConnection(this, client);
    auto connId = conn->connId();
    {
        const QMutexLocker locker(&m_connectionsLock);
        connections[connId] = conn;
    }
    connect(conn, &QObject::destroyed, this, [this, connId] {
        const QMutexLocker locker(&m_connectionsLock);
        connections.remove(connId);
    });

    qInfo().noquote() << addr << "connected, connId:" << connId;

    connect(conn, &UserConnection::notificationGot, this, [this, conn](const QByteArray &command, const QByteArray &data) {
        L->callKTabletopMethod(u"server"_s,
                               u"processNotification"_s,
                               {
                                   conn->connId(),
                                   QString::fromUtf8(command),
                                   QJsonValue::fromJson(data).toVariant(),
                               });
    });

    connect(conn, &UserConnection::requestGot, this, [this, conn](int requestId) {
        const auto &req = conn->receivedRequest(requestId);
        L->callKTabletopMethod(u"server"_s,
                               u"processRequest"_s,
                               {
                                   conn->connId(),
                                   requestId,
                                   QString::fromUtf8(req.command),
                                   QJsonValue::fromJson(req.jsonData).toVariant(),
                                   req.timeout,
                               });
    });

    connect(conn, &UserConnection::disconnected, this, [this, conn, connId, addr] {
        L->callKTabletopMethod(u"server"_s, u"processDisconnected"_s, {connId});
        conn->deleteLater();
    });

    L->callKTabletopMethod(u"server"_s, u"processNewConnection"_s, {connId});
}
