// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "server.h"
#include "client-socket.h"
#include "lua-binding.h"
#include "server-socket.h"
#include "user-connection.h"

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

    L->emit(u"KTabletop::Socket::NewConnection"_s, {{u"connId"_s, connId}});
}
