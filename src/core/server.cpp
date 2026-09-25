// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "server.h"
#include "db-thread.h"
#include "game-thread.h"
#include "ktabletop-lua.h"
#include "lua/lua-binding.h"
#include "network/client-socket.h"
#include "network/crypto-util.h"
#include "network/server-socket.h"
#include "network/user-connection.h"
#include "util.h"

#include <QJsonDocument>
#include <QJsonValue>

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

static constexpr char usersDbSql[] = {
#embed "users-init.sql"
};

// NOTE: DO NOT contain any ';' in comments of .sql file
static const auto usersDbSchema = QString::fromUtf8(usersDbSql);

Server::Server(QObject *parent)
    : QObject(parent)
{
    L = new LuaBinding(this, LuaBinding::Server);
    luaopen_ktabletop(L->state());
    L->run();

    initAuthKeys();

    server = new ServerSocket(this);
    connect(server, &ServerSocket::newConnection, this, &Server::processNewConnection);

    m_usersDb = new DbThread(this, u"usersDb"_s, u"./server/users.db"_s);
    m_usersDb->execMultiSql(usersDbSchema);
}

Server::~Server()
{
    EVP_PKEY_free(m_authPrivateKey);
    serverInstance = nullptr;
}

void Server::initAuthKeys()
{
    static const QString privPath = u"./server/ed25519.key"_s;
    static const QString pubPath = u"./server/ed25519.key.pub"_s;

    if (!QFile::exists(privPath) || !QFile::exists(pubPath)) {
        EVP_PKEY *pkey = generateEd25519KeyPairs();
        if (!pkey) {
            qFatal("Failed to generate Ed25519 key pair");
        }
        if (!writeKeyPair(privPath, pubPath, pkey)) {
            EVP_PKEY_free(pkey);
            qFatal("Failed to write Ed25519 key pair to server/");
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
    }
    return ret;
}

UserConnection *Server::findConnection(int connId) const
{
    return connections.value(connId);
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

void Server::dispatchLuaEvent(const QString &type, const QVariant &data)
{
    L->callKTabletopMethod(u"server"_s, u"dispatchLuaEvent"_s, {type, data});
}

void Server::processNewConnection(ClientSocket *client)
{
    auto *socket = client->socket();
    auto addr = QString(u"[%1]:%2"_s).arg(socket->peerAddress().toString()).arg(socket->peerPort());
    qInfo() << addr << "connected";

    auto *conn = new UserConnection(this, client);
    auto connId = conn->connId();
    connections[connId] = conn;
    connect(conn, &QObject::destroyed, this, [this, connId] {
        connections.remove(connId);
    });

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
