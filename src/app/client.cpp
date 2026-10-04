// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client.h"
#include "client-lua.h"
#include "core/common-lua.h"
#include "core/packman.h"
#include "lua/lua-binding.h"
#include "network/client-socket.h"
#include "network/user-connection.h"

#include <QJsonDocument>
#include <QJsonObject>

#include <KLocalizedString>

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
    luaopen_ktabletop_common(L->state());
    luaopen_ktabletop_client(L->state());
    L->setRuntimePaths(PackMan::instance()->listPluginPaths());

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

    connect(m_connection->socket()->socket(), &QTcpSocket::errorOccurred, this, &Client::raiseSocketError);
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

void Client::startTask(const QString &key, const QString &message, int progress, bool cancelable, std::move_only_function<void()> cancelFn)
{
    if (cancelable && cancelFn) {
        m_taskCancels.emplace(key, std::move(cancelFn));
    }

    Q_EMIT setProgressDialogData(key, message, progress, cancelable);
}

void Client::updateTask(const QString &key, int progress, const QString &message)
{
    Q_EMIT setProgressDialogData(key, message, progress, m_taskCancels.contains(key));

    if (progress >= 100) {
        m_taskCancels.extract(key);
        Q_EMIT clearProgressDialogData(key);
    }
}

void Client::cancelTask(const QString &key)
{
    if (!m_taskCancels.contains(key)) {
        return;
    }

    auto node = m_taskCancels.extract(key);

    Q_EMIT clearProgressDialogData(key);

    if (!node.empty()) {
        node.mapped()();
    }
}

void Client::raiseSocketError(QAbstractSocket::SocketError socket_error)
{
    QString reason;
    switch (socket_error) {
    case QAbstractSocket::ConnectionRefusedError:
        reason = i18nc("@socket-error", "Connection was refused or timeout");
        break;
    case QAbstractSocket::RemoteHostClosedError:
        reason = i18nc("@socket-error", "Remote host close this connection");
        break;
    case QAbstractSocket::HostNotFoundError:
        reason = i18nc("@socket-error", "Host not found");
        break;
    case QAbstractSocket::SocketAccessError:
        reason = i18nc("@socket-error", "Socket access error");
        break;
    case QAbstractSocket::SocketResourceError:
        reason = i18nc("@socket-error", "Socket resource error");
        break;
    case QAbstractSocket::SocketTimeoutError:
        reason = i18nc("@socket-error", "Socket timeout error");
        break;
    case QAbstractSocket::DatagramTooLargeError:
        reason = i18nc("@socket-error", "Datagram too large error");
        break;
    case QAbstractSocket::NetworkError:
        reason = i18nc("@socket-error", "Network error");
        break;
    case QAbstractSocket::UnsupportedSocketOperationError:
        reason = i18nc("@socket-error", "Unsupported socket operation");
        break;
    case QAbstractSocket::UnfinishedSocketOperationError:
        reason = i18nc("@socket-error", "Unfinished socket operation");
        break;
    case QAbstractSocket::ProxyAuthenticationRequiredError:
        reason = i18nc("@socket-error", "Proxy auth error");
        break;
    case QAbstractSocket::ProxyConnectionRefusedError:
        reason = i18nc("@socket-error", "Proxy refused");
        break;
    case QAbstractSocket::ProxyConnectionClosedError:
        reason = i18nc("@socket-error", "Proxy closed");
        break;
    case QAbstractSocket::ProxyConnectionTimeoutError:
        reason = i18nc("@socket-error", "Proxy timeout");
        break;
    case QAbstractSocket::ProxyProtocolError:
        reason = i18nc("@socket-error", "Proxy protocol error");
        break;
    case QAbstractSocket::OperationError:
        reason = i18nc("@socket-error", "Operation error");
        break;
    case QAbstractSocket::TemporaryError:
        reason = i18nc("@socket-error", "Temporary error");
        break;
    default:
        reason = i18nc("@socket-error", "Unknown error");
        break;
    }

    auto msg = i18n("Connection failed, error code = %1\nreason: %2", socket_error, reason);
    L->callKTabletopMethod(u"client"_s, u"onSocketError"_s, {msg});
}
