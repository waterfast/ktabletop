// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client.h"
#include "ktabletop-lua.h"
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
    luaopen_ktabletop(L->state());
    L->run();

    connection_ = new UserConnection(this, new ClientSocket);

    connect(connection_, &UserConnection::notificationGot, [this](const QByteArray &command, const QByteArray &jsonData) {
        L->callMethod(u"client"_s, u"processNotification"_s, {connection_->connId(), QString::fromUtf8(command), QJsonValue::fromJson(jsonData).toVariant()});
    });

    connect(connection_, &UserConnection::requestGot, [this, conn = connection_](int requestId) {
        const auto &req = conn->receivedRequest(requestId);
        L->callMethod(u"client"_s,
                      u"processRequest"_s,
                      {conn->connId(), requestId, QString::fromUtf8(req.command), QJsonValue::fromJson(req.jsonData).toVariant()});
    });

    connect(connection_, &UserConnection::socketError, [this](const QString &msg) {
        L->callMethod(u"client"_s, u"onSocketError"_s, {msg});
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
    L->callMethod(u"client"_s, u"connectToHost"_s, {server, port});
}
