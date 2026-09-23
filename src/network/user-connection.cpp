// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "user-connection.h"
#include "client-socket.h"

#include <QCborArray>
#include <QCborValue>
#include <QFuture>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

#include <atomic>

using namespace Qt::StringLiterals;

UserConnection::UserConnection(QObject *parent, ClientSocket *socket)
    : QObject(parent)
{
    qRegisterMetaType<ReplyCallback>("UserConnection::ReplyCallback");

    setSocket(socket);

    static int nextConnId = 1000;
    m_connId = nextConnId++;
    if (nextConnId >= 0xFFFFFF)
        nextConnId = 1000;
}

UserConnection::~UserConnection()
{
}

int UserConnection::connId() const
{
    return m_connId;
}

ClientSocket *UserConnection::socket() const
{
    return m_socket;
}

void UserConnection::setSocket(ClientSocket *socket)
{
    if (m_socket != nullptr) {
        m_socket->disconnect(this);
        disconnect(m_socket);
        m_socket->deleteLater();
    }

    m_socket = nullptr;
    if (socket != nullptr) {
        connect(this, &UserConnection::messageReady, socket, &ClientSocket::send);
        connect(socket, &ClientSocket::messageGot, this, &UserConnection::handlePacket);
        connect(socket, &ClientSocket::errorMessage, this, &UserConnection::socketError);
        connect(socket, &ClientSocket::disconnected, this, &UserConnection::disconnected);
        socket->setParent(this);
        m_socket = socket;
    }
}

ClientSocket *UserConnection::moveSocket()
{
    auto *socket = m_socket;
    m_socket = nullptr;
    socket->disconnect(this);
    socket->setParent(nullptr);
    return socket;
}

int UserConnection::nextRequestId()
{
    static std::atomic<int> counter{0};
    int id = ++counter;
    if (id > 10000000) {
        counter = 1;
        id = 1;
    }
    return id;
}

int UserConnection::request(const QByteArray &command, const QByteArray &jsonData, int timeout, qint64 timestamp, ReplyCallback callback)
{
    const int id = nextRequestId();
    auto data = jsonData;
    int type = UserConnection::TypeRequest;
    if (jsonData.size() > COMPRESSION_THRESHOLD) {
        data = qCompress(jsonData);
        type |= UserConnection::DataCompressed;
    }
    if (timestamp <= 0) {
        timestamp = QDateTime::currentDateTime().toMSecsSinceEpoch();
    }
    QCborArray body{id, type, command, data, timeout, timestamp};
    auto msg = body.toCborValue().toCbor();

    if (!callback) {
        sendMessage(msg);
        return id;
    }

    auto promise = std::make_shared<QPromise<RequestResult>>();
    promise->start();
    promise->future().then(this, [cb = std::move(callback)](RequestResult result) {
        cb(result.first, result.second);
    });

    m_pendingRequestLock.lock();
    m_pendingRequests.insert(id, promise);
    m_pendingRequestLock.unlock();
    sendMessage(msg);

    if (timeout <= 0) {
        return id;
    }

    QTimer::singleShot(timeout * 1000, this, [this, id, promise] {
        QMutexLocker locker(&m_pendingRequestLock);
        auto it = m_pendingRequests.find(id);
        if (it == m_pendingRequests.end() || *it != promise)
            return;

        m_pendingRequests.erase(it);
        locker.unlock();
        QJsonObject payload{{u"requestId"_s, id}};
        notify("Socket::CancelRequest", QJsonDocument(payload).toJson(QJsonDocument::Compact));
        promise->emplaceResult(std::make_error_code(std::errc::timed_out), QByteArray{});
        promise->finish();
    });

    return id;
}

void UserConnection::reply(int requestId, bool ok, const QByteArray &jsonData)
{
    auto data = jsonData;
    int type = TypeReply;
    if (jsonData.size() > COMPRESSION_THRESHOLD) {
        data = qCompress(jsonData);
        type |= DataCompressed;
    }

    if (ok) {
        type |= ReplyOk;
    } else {
        type |= ReplyError;
    }

    QCborArray body{requestId, type, QByteArray(), data};

    sendMessage(body.toCborValue().toCbor());
    m_receivedRequests.remove(requestId);
}

void UserConnection::notify(const QByteArray &command, const QByteArray &jsonData)
{
    auto data = jsonData;
    int type = TypeNotification;
    if (jsonData.size() > COMPRESSION_THRESHOLD) {
        data = qCompress(jsonData);
        type |= DataCompressed;
    }

    QCborArray body{-2, type, command, data};

    sendMessage(body.toCborValue().toCbor());
}

UserConnection::ReceivedRequest UserConnection::receivedRequest(int requestId) const
{
    return m_receivedRequests.value(requestId);
}

// Tell the peer to cancel the running handler of `requestId`, and drop the
// local pending request without invoking its callback.
void UserConnection::cancelRequest(int requestId)
{
    QJsonObject payload{{u"requestId"_s, requestId}};
    notify("Socket::CancelRequest", QJsonDocument(payload).toJson(QJsonDocument::Compact));

    QMutexLocker locker(&m_pendingRequestLock);
    m_pendingRequests.remove(requestId);
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
        Q_EMIT notificationGot(command, jsonData);
    } else if (type & TypeRequest) {
        ReceivedRequest rr{requestId, command, jsonData, int(packet[4].toInteger()), packet[5].toInteger()};
        m_receivedRequests.insert(requestId, rr);
        Q_EMIT requestGot(requestId);
    } else if (type & TypeReply) {
        m_pendingRequestLock.lock();
        auto promise = m_pendingRequests.take(requestId);
        m_pendingRequestLock.unlock();
        if (!promise)
            return;

        bool ok = type & ReplyOk;
        std::error_code error{};
        if (!ok) {
            error = std::make_error_code(std::errc::bad_message);
        }

        promise->emplaceResult(error, jsonData);
        promise->finish();
    }
}

void UserConnection::sendMessage(const QByteArray &msg)
{
    Q_EMIT messageReady(msg);
}
