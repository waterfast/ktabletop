// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client.h"
#include "client-lua-plugin.h"
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
    L->loadPlugin(ClientLuaPlugin::create());

    connection_ = new UserConnection(this, new ClientSocket);

    connect(connection_, &UserConnection::notificationGot, [this](const QByteArray &command, const QByteArray &jsonData) {
        L->emit(u"Core::Socket::NotificationGot"_s,
                {
                    {u"connId"_s, connection_->connId()},
                    {u"command"_s, QString::fromUtf8(command)},
                    {u"data"_s, QJsonValue::fromJson(jsonData).toVariant()},
                });
    });

    connect(connection_, &UserConnection::requestGot, [this, conn = connection_](int requestId) {
        const auto &req = conn->receivedRequest(requestId);
        L->emit(u"Core::Socket::RequestGot"_s,
                {
                    {u"connId"_s, conn->connId()},
                    {u"requestId"_s, requestId},
                    {u"command"_s, QString::fromUtf8(req.command)},
                    {u"data"_s, QJsonValue::fromJson(req.jsonData).toVariant()},
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

UserConnection *Client::connection() const
{
    return connection_;
}

void Client::connectToHost(const QString &server, ushort port)
{
    L->emit(u"Client::ConnectToHost"_s, {{u"host"_s, server}, {u"port"_s, port}});
}
