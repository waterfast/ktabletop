// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "server.h"
#include "ktabletop-lua.h"
#include "lua/lua-binding.h"
#include "network/client-socket.h"
#include "network/server-socket.h"
#include "network/user-connection.h"

#include <QJsonDocument>
#include <QJsonValue>

using namespace Qt::Literals::StringLiterals;

static Server *serverInstance = nullptr;

Server *Server::instance()
{
    if (!serverInstance) {
        serverInstance = new Server;
    }
    return serverInstance;
}

Server::Server(QObject *parent)
    : QObject(parent)
{
    L = new LuaBinding(this, LuaBinding::Server);
    luaopen_ktabletop(L->state());
    L->run();

    server = new ServerSocket(this);
    connect(server, &ServerSocket::newConnection, this, &Server::processNewConnection);
}

Server::~Server()
{
    serverInstance = nullptr;
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

void Server::processNewConnection(ClientSocket *client)
{
    auto socket = client->socket();
    auto addr = QString(u"[%1]:%2"_s).arg(socket->peerAddress().toString()).arg(socket->peerPort());
    qInfo() << addr << "connected";

    auto conn = new UserConnection(this, client);
    auto connId = conn->connId();
    connections[connId] = conn;
    connect(conn, &QObject::destroyed, [this, connId] {
        connections.remove(connId);
    });

    connect(conn, &UserConnection::requestGot, [this, conn](int requestId) {
        const auto &req = conn->receivedRequest(requestId);
        L->call(u"server"_s, u"processRequest"_s, {conn->connId(), requestId, QString::fromUtf8(req.command), QJsonValue::fromJson(req.jsonData).toVariant()});
    });

    L->call(u"server"_s, u"onNewConnection"_s, {connId});
}
