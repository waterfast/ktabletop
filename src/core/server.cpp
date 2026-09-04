// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "server.h"
#include "common-lua-plugin.h"
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
    L->loadPlugin(CommonLuaPlugin::create());

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
        L->emit(u"Core::Socket::RequestGot"_s,
                {
                    {u"connId"_s, conn->connId()},
                    {u"requestId"_s, requestId},
                    {u"command"_s, QString::fromUtf8(req.command)},
                    {u"data"_s, QJsonValue::fromJson(req.jsonData).toVariant()},
                });
    });

    L->emit(u"Socket::NewConnection"_s, {{u"connId"_s, connId}});
}
