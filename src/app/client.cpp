// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client.h"
#include "client-socket.h"
#include "lua-binding.h"
#include "user-connection.h"

static Client *clientInstance = nullptr;

Client *Client::instance()
{
    if (!clientInstance) {
        clientInstance = new Client;
    }
    return clientInstance;
}

Client::Client(QObject *parent)
    : QObject(parent)
{
    L = new LuaBinding(this, LuaBinding::Client);
    connection = new UserConnection(this, new ClientSocket);

    connect(connection, &UserConnection::notificationGot, [](const QByteArray &command, const QByteArray &jsonData) {
        qDebug() << "RX: command=" << command.constData() << ", data=" << jsonData.constData();
    });
}

Client::~Client()
{
    clientInstance = nullptr;
}

void Client::connectToHost(const QString &server, ushort port)
{
    connection->socket()->socket()->connectToHost(server, port);
}
