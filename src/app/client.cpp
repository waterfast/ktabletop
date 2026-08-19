// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client.h"
#include "client-socket.h"
#include "lua-binding.h"
#include "user-connection.h"

#include <QJsonDocument>
#include <QJsonObject>

using namespace Qt::Literals::StringLiterals;

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

    connect(connection, &UserConnection::notificationGot, [this](const QByteArray &command, const QByteArray &jsonData) {
        L->emit(u"KTableTopCpp::Socket::NotificationGot"_s,
                QJsonObject{
                    {u"connId"_s, connection->connId()},
                    {u"command"_s, QString::fromUtf8(command)},
                    {u"data"_s, QJsonValue::fromJson(jsonData)},
                });
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
