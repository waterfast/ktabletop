// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QDateTime>
#include <QHash>
#include <QObject>

#include <functional>
#include <system_error>

class ClientSocket;
class PendingRequest;

class UserConnection : public QObject
{
    Q_OBJECT

public:
    enum PacketType {
        DataCompressed = 0x1000,

        TypeRequest = 0x100,
        TypeReply = 0x200,
        TypeNotification = 0x400,

        ReplyOk = 0x10,
        ReplyError = 0x20,
    };

    struct ReceivedRequest {
        int requestId = 0;
        QByteArray command;
        QByteArray jsonData;
        int timeout = 0;
        qint64 timestamp = 0;
    };

    using ReplyCallback = std::function<void(std::error_code error, QByteArray reply)>;

    UserConnection(QObject *parent, ClientSocket *socket = nullptr);
    ~UserConnection();

    int connId() const;

    ClientSocket *socket() const;
    void setSocket(ClientSocket *socket);
    ClientSocket *moveSocket();

    int request(const QByteArray &command, const QByteArray &jsonData, int timeout, qint64 timestamp = -1, ReplyCallback callback = {});
    void reply(int requestId, bool ok, const QByteArray &jsonData);
    void notify(const QByteArray &command, const QByteArray &jsonData);

    ReceivedRequest receivedRequest(int requestId) const;

    void cancelRequest(int requestId);

Q_SIGNALS:
    void messageReady(const QByteArray &msg);

    void notificationGot(const QByteArray &command, const QByteArray &jsonData);
    void requestGot(int requestId);
    void socketError(const QString &msg);
    void disconnected();

protected:
    void handlePacket(const QCborArray &packet);

private:
    // Sending side
    friend class PendingRequest;
    QHash<int, PendingRequest *> m_pendingRequests;

    // Receiving side
    QHash<int, ReceivedRequest> m_receivedRequests;

    ClientSocket *m_socket = nullptr;
    int m_connId;

    enum {
        COMPRESSION_THRESHOLD = 2048
    };

    void sendMessage(const QByteArray &msg);
};
