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

bool Client::initialized()
{
    return clientInstance != nullptr;
}

void Client::destroy()
{
    delete clientInstance;
    clientInstance = nullptr;
}

Client::Client(QObject *parent)
    : QObject(parent)
{
    L = new LuaBinding(this, LuaBinding::Client);
    luaopen_ktabletop(L->state());
    L->run();

    m_connection = new UserConnection(this, new ClientSocket);
    m_connection->setClientSide(true);

    connect(m_connection, &UserConnection::notificationGot, this, [this](const QByteArray &command, const QByteArray &jsonData) {
        L->callKTabletopMethod(u"client"_s,
                               u"processNotification"_s,
                               {
                                   m_connection->connId(),
                                   QString::fromUtf8(command),
                                   QJsonValue::fromJson(jsonData).toVariant(),
                               });
    });

    connect(m_connection, &UserConnection::requestGot, this, [this, conn = m_connection](int requestId) {
        const auto &req = conn->receivedRequest(requestId);
        L->callKTabletopMethod(u"client"_s,
                               u"processRequest"_s,
                               {
                                   conn->connId(),
                                   requestId,
                                   QString::fromUtf8(req.command),
                                   QJsonValue::fromJson(req.jsonData).toVariant(),
                                   req.timeout,
                               });
    });

    connect(m_connection, &UserConnection::socketError, this, [this](const QString &msg) {
        L->callKTabletopMethod(u"client"_s, u"onSocketError"_s, {msg});
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
    return m_connection;
}

void Client::connectToHost(const QString &server, ushort port, const QString &username, const QString &password)
{
    L->callKTabletopMethod(u"client"_s, u"connectToHost"_s, {server, port, username, password});
}

void Client::setTaskStatus(const QString &key, const QString &message, int progress, bool cancelable, std::function<void()> cancelFn)
{
}

void Client::completeTask(const QString &key)
{
}
