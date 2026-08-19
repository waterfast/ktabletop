// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "server-socket.h"
#include "client-socket.h"

ServerSocket::ServerSocket(QObject *parent)
    : QObject(parent)
{
    server = new QTcpServer(this);
    connect(server, &QTcpServer::newConnection, this, &ServerSocket::processNewConnection);
}

bool ServerSocket::listen(const QHostAddress &address, ushort port)
{
    return server->listen(address, port);
}

void ServerSocket::processNewConnection()
{
    QTcpSocket *socket = server->nextPendingConnection();
    ClientSocket *connection = new ClientSocket(nullptr, socket);
    newConnection(connection);
}
