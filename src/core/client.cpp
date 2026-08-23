// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client.h"
#include "common-lua-plugin.h"
#include "lua/lua-binding.h"
#include "network/client-socket.h"
#include "network/user-connection.h"

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
    L->loadPlugin(CommonLuaPlugin::create());

    connection = new UserConnection(this, new ClientSocket);

    connect(connection, &UserConnection::notificationGot, [this](const QByteArray &command, const QByteArray &jsonData) {
        L->emit(u"KTabletopCpp::Socket::NotificationGot"_s,
                {
                    {u"connId"_s, connection->connId()},
                    {u"command"_s, QString::fromUtf8(command)},
                    {u"data"_s, QJsonValue::fromJson(jsonData).toVariant()},
                });
    });
}

Client::~Client()
{
    clientInstance = nullptr;
}

LuaBinding *Client::luaBinding() const
{
    return L;
}

void Client::connectToHost(const QString &server, ushort port)
{
    connection->socket()->socket()->connectToHost(server, port);
}
