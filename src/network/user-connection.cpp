// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "user-connection.h"
#include "client-socket.h"

#include <QCborArray>
#include <QCborValue>
#include <QTimer>

class PendingRequest : public QObject
{
public:
    PendingRequest(UserConnection *conn, int id, UserConnection::ReplyCallback callback, int timeout)
        : QObject(conn)
        , m_conn(conn)
        , m_id(id)
        , m_callback(std::move(callback))
        , m_timeout(timeout)
    {
        if (m_callback && timeout > 0) {
            m_timer = new QTimer(this);
            m_timer->setSingleShot(true);
            connect(m_timer, &QTimer::timeout, this, [this]() {
                finish(QByteArray{}, std::make_error_code(std::errc::timed_out));
            });
            m_timer->start(timeout * 1000);
        }
    }

    void send(const QByteArray &command, const QByteArray &jsonData, qint64 timestamp)
    {
        auto data = jsonData;
        int type = UserConnection::TypeRequest;
        if (jsonData.size() > UserConnection::COMPRESSION_THRESHOLD) {
            data = qCompress(jsonData);
            type |= UserConnection::DataCompressed;
        }

        QCborArray body{
            m_id,
            type,
            command,
            data,
            m_timeout,
            (timestamp <= 0 ? QDateTime::currentDateTime().toMSecsSinceEpoch() : timestamp),
        };

        m_conn->sendMessage(body.toCborValue().toCbor());
    }

    void finish(const QByteArray &reply, std::error_code err)
    {
        m_conn->m_pendingRequests.remove(m_id);
        if (m_timer)
            m_timer->stop();
        if (m_callback) {
            auto cb = std::move(m_callback);
            cb(err, reply);
        }
        deleteLater();
    }

private:
    UserConnection *m_conn;
    int m_id;
    UserConnection::ReplyCallback m_callback;
    int m_timeout;
    QTimer *m_timer = nullptr;
};

UserConnection::UserConnection(QObject *parent, ClientSocket *socket)
    : QObject(parent)
{
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

int UserConnection::request(const QByteArray &command, const QByteArray &jsonData, int timeout, qint64 timestamp, ReplyCallback callback)
{
    static int requestId = 0;
    requestId++;
    if (requestId > 10000000)
        requestId = 1;

    const bool tracked = static_cast<bool>(callback);
    auto *req = new PendingRequest(this, requestId, std::move(callback), timeout);
    if (tracked) {
        m_pendingRequests.insert(requestId, req);
    }
    req->send(command, jsonData, timestamp);
    if (!tracked)
        req->deleteLater();

    return requestId;
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

    QCborArray body{
        requestId,
        type,
        QByteArray(),
        data,
    };

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

    QCborArray body{
        -2,
        type,
        command,
        data,
    };

    sendMessage(body.toCborValue().toCbor());
}

UserConnection::ReceivedRequest UserConnection::receivedRequest(int requestId) const
{
    return m_receivedRequests.value(requestId);
}

// cancel last request from the sender
void UserConnection::cancelRequest(int requestId)
{
    auto *req = m_pendingRequests.value(requestId, nullptr);
    if (!req)
        return;
    req->finish(QByteArray{}, std::make_error_code(std::errc::timed_out));
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
        ReceivedRequest rr{
            requestId,
            command,
            jsonData,
            int(packet[4].toInteger()),
            packet[5].toInteger(),
        };
        m_receivedRequests.insert(requestId, rr);
        requestGot(requestId);
    } else if (type & TypeReply) {
        auto *req = m_pendingRequests.value(requestId, nullptr);
        if (!req)
            return;

        bool ok = type & ReplyOk;
        std::error_code error{};
        if (!ok) {
            error = std::make_error_code(std::errc::bad_message);
        }

        req->finish(jsonData, error);
    }
}

void UserConnection::sendMessage(const QByteArray &msg)
{
    messageReady(msg);
}
