// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "user-connection.h"
#include "client-socket.h"

#include <QCborArray>
#include <QCborValue>

UserConnection::UserConnection(QObject *parent, ClientSocket *socket)
    : QObject(parent)
{
    setSocket(socket);
    expectedReplyIds.clear();
    replyTimeout = 0;
    extraReplyReadySemaphore = nullptr;

    static int nextConnId = 1000;
    connId_ = nextConnId++;
    if (nextConnId >= 0xFFFFFF)
        nextConnId = 1000;
}

UserConnection::~UserConnection()
{
}

int UserConnection::connId() const
{
    return connId_;
}

ClientSocket *UserConnection::socket() const
{
    return socket_;
}

void UserConnection::setSocket(ClientSocket *socket)
{
    if (socket_ != nullptr) {
        socket_->disconnect(this);
        disconnect(socket_);
        socket_->deleteLater();
    }

    socket_ = nullptr;
    if (socket != nullptr) {
        connect(this, &UserConnection::messageReady, socket, &ClientSocket::send);
        connect(socket, &ClientSocket::messageGot, this, &UserConnection::handlePacket);
        socket->setParent(this);
        socket_ = socket;
    }
}

ClientSocket *UserConnection::moveSocket()
{
    auto socket = socket_;
    socket_ = nullptr;
    socket->disconnect(this);
    socket->setParent(nullptr);
    return socket;
}

void UserConnection::setReplyReadySemaphore(QSemaphore *semaphore)
{
    extraReplyReadySemaphore = semaphore;
}

void UserConnection::request(const QByteArray &command, const QByteArray &jsonData, int timeout, qint64 timestamp)
{
    // In case a request is called without a following waitForReply call
    if (replyReadySemaphore.available() > 0)
        replyReadySemaphore.acquire(replyReadySemaphore.available());

    static int requestId = 0;
    requestId++;
    if (requestId > 10000000)
        requestId = 1;

    replyMutex.lock();
    expectedReplyIds.push_back(requestId);
    replyTimeout = timeout;
    requestStartTime = QDateTime::currentDateTime();
    m_reply = QByteArrayLiteral("__notready");
    replyMutex.unlock();

    auto data = jsonData;
    int type = TypeRequest;
    if (jsonData.size() > COMPRESSION_THRESHOLD) {
        data = qCompress(jsonData);
        type |= DataCompressed;
    }

    QCborArray body{requestId, type, command, data, timeout, (timestamp <= 0 ? requestStartTime.toMSecsSinceEpoch() : timestamp)};

    sendMessage(body.toCborValue().toCbor());
}

void UserConnection::reply(const QByteArray &jsonData)
{
    auto data = jsonData;
    int type = TypeReply;
    if (jsonData.size() > COMPRESSION_THRESHOLD) {
        data = qCompress(jsonData);
        type |= DataCompressed;
    }

    QCborArray body{
        requestId_,
        type,
        QByteArray(),
        data,
    };

    sendMessage(body.toCborValue().toCbor());
}

void UserConnection::notify(const QByteArray &command, const QByteArray &jsonData)
{
    auto data = jsonData;
    int type = TypeNotification;
    if (jsonData.size() > COMPRESSION_THRESHOLD) {
        data = qCompress(jsonData);
        type |= DataCompressed;
    }

    QCborArray body{
        -2,
        type,
        command,
        data,
    };

    sendMessage(body.toCborValue().toCbor());
}

int UserConnection::requestTimeout() const
{
    return requestTimeout_;
}

// cancel last request from the sender
void UserConnection::cancelRequest()
{
    replyMutex.lock();
    expectedReplyIds.pop_back();
    replyTimeout = 0;
    extraReplyReadySemaphore = nullptr;
    replyMutex.unlock();

    if (replyReadySemaphore.available() > 0)
        replyReadySemaphore.acquire(replyReadySemaphore.available());
}

QByteArray UserConnection::waitForReply(int timeout)
{
    QByteArray ret;
    replyReadySemaphore.tryAcquire(1, timeout * 1000);
    replyMutex.lock();
    ret = m_reply;
    replyMutex.unlock();
    return ret;
}

void UserConnection::handlePacket(const QCborArray &packet)
{
    int requestId = packet[0].toInteger();
    int type = packet[1].toInteger();
    auto command = packet[2].toByteArray();
    auto jsonData = packet[3].toByteArray();

    if (type & DataCompressed) {
        jsonData = qUncompress(jsonData);
    }

    if (type & TypeNotification) {
        notificationGot(command, jsonData);
    } else if (type & TypeRequest) {
        requestId_ = requestId;
        requestTimeout_ = packet[4].toInteger();
        requestTimestamp_ = packet[5].toInteger();

        requestGot(command, jsonData);
    } else if (type & TypeReply) {
        QMutexLocker locker(&replyMutex);

        auto it = std::find(expectedReplyIds.begin(), expectedReplyIds.end(), requestId);
        if (it == expectedReplyIds.end())
            return;

        expectedReplyIds.erase(it);

        if (replyTimeout >= 0 && replyTimeout < requestStartTime.secsTo(QDateTime::currentDateTime()))
            return;

        m_reply = jsonData;

        replyReadySemaphore.release();
        if (extraReplyReadySemaphore) {
            extraReplyReadySemaphore->release();
            extraReplyReadySemaphore = nullptr;
        }

        locker.unlock();
        replyReady();
    }
}

void UserConnection::sendMessage(const QByteArray &msg)
{
    messageReady(msg);
}
