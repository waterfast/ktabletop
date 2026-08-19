// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QDateTime>
#include <QMutex>
#include <QObject>
#include <QSemaphore>

class ClientSocket;

class UserConnection : public QObject
{
    Q_OBJECT

public:
    enum PacketType {
        DataCompressed = 0x1000,

        TypeRequest = 0x100,
        TypeReply = 0x200,
        TypeNotification = 0x400,
        DestClient = 0x001,
        DestServer = 0x002,
    };

    UserConnection(QObject *parent, ClientSocket *socket);
    ~UserConnection();

    int connId() const;

    ClientSocket *socket() const;
    void setSocket(ClientSocket *socket);
    ClientSocket *moveSocket();

    void setReplyReadySemaphore(QSemaphore *semaphore);

    void request(int type, const QByteArray &command, const QByteArray &jsonData, int timeout, qint64 timestamp = -1);
    void reply(int type, const QByteArray &command, const QByteArray &jsonData);
    void notify(int type, const QByteArray &command, const QByteArray &jsonData);

    int requestTimeout() const;

    void cancelRequest();

    QByteArray waitForReply(int timeout);

    int requestId() const;
    qint64 requestTimestamp() const;

Q_SIGNALS:
    void messageReady(const QByteArray &msg);
    void replyReady();

    void notificationGot(const QByteArray &command, const QByteArray &jsonData);
    void requestGot(const QByteArray &command, const QByteArray &jsonData);

protected:
    void handlePacket(const QCborArray &packet);

private:
    ClientSocket *socket_;
    int connId_;

    // For client side
    int requestId_;
    int requestTimeout_;
    qint64 requestTimestamp_;

    // For server side
    QDateTime requestStartTime;
    QMutex replyMutex;
    std::vector<int> expectedReplyIds;
    int replyTimeout;
    QByteArray m_reply; // should be json string
    QSemaphore replyReadySemaphore;
    QSemaphore *extraReplyReadySemaphore;

    enum {
        COMPRESSION_THRESHOLD = 2048
    };

    void sendMessage(const QByteArray &msg);
};
