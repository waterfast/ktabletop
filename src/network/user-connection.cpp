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
        , conn_(conn)
        , id_(id)
        , callback_(std::move(callback))
        , timeout_(timeout)
    {
        if (callback_ && timeout > 0) {
            timer_ = new QTimer(this);
            timer_->setSingleShot(true);
            connect(timer_, &QTimer::timeout, this, [this]() {
                finish(QByteArray{}, std::make_error_code(std::errc::timed_out));
            });
            timer_->start(timeout * 1000);
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
            id_,
            type,
            command,
            data,
            timeout_,
            (timestamp <= 0 ? QDateTime::currentDateTime().toMSecsSinceEpoch() : timestamp),
        };

        conn_->sendMessage(body.toCborValue().toCbor());
    }

    void finish(const QByteArray &reply, std::error_code err)
    {
        conn_->pendingRequests_.remove(id_);
        if (timer_)
            timer_->stop();
        if (callback_) {
            auto cb = std::move(callback_);
            cb(err, reply);
        }
        deleteLater();
    }

private:
    UserConnection *conn_;
    int id_;
    UserConnection::ReplyCallback callback_;
    int timeout_;
    QTimer *timer_ = nullptr;
};

UserConnection::UserConnection(QObject *parent, ClientSocket *socket)
    : QObject(parent)
{
    setSocket(socket);

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
        connect(socket, &ClientSocket::errorMessage, this, &UserConnection::socketError);
        connect(socket, &ClientSocket::disconnected, this, &UserConnection::disconnected);
        socket->setParent(this);
        socket_ = socket;
    }
}

ClientSocket *UserConnection::moveSocket()
{
    auto *socket = socket_;
    socket_ = nullptr;
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
        pendingRequests_.insert(requestId, req);
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
    receivedRequests_.remove(requestId);
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
    return receivedRequests_.value(requestId);
}

// cancel last request from the sender
void UserConnection::cancelRequest(int requestId)
{
    auto *req = pendingRequests_.value(requestId, nullptr);
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
        receivedRequests_.insert(requestId, rr);
        requestGot(requestId);
    } else if (type & TypeReply) {
        auto *req = pendingRequests_.value(requestId, nullptr);
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
