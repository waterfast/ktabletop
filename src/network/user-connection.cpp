// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "user-connection.h"
#include "client-socket.h"
#include "crypto-util.h"

#include <QCborArray>
#include <QCborValue>
#include <QFuture>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

#include <atomic>

using namespace Qt::StringLiterals;
using namespace KTabletopCrypto;

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
    EVP_PKEY_free(m_authEphemeralKey);
}

void UserConnection::setAuthEphemeralKey(EVP_PKEY *key)
{
    EVP_PKEY_free(m_authEphemeralKey);
    m_authEphemeralKey = key;
}

EVP_PKEY *UserConnection::takeAuthEphemeralKey()
{
    EVP_PKEY *key = m_authEphemeralKey;
    m_authEphemeralKey = nullptr;
    return key;
}

void UserConnection::setAuthNonce(const QByteArray &nonce)
{
    m_authNonce = nonce;
}

QByteArray UserConnection::authNonce() const
{
    return m_authNonce;
}

void UserConnection::setPeerEphPublicKey(const QByteArray &key)
{
    m_peerEphPublicKey = key;
}

QByteArray UserConnection::peerEphPublicKey() const
{
    return m_peerEphPublicKey;
}

void UserConnection::setClientSide(bool clientSide)
{
    m_clientSide = clientSide;
}

void UserConnection::enableEncryption(const QByteArray &key)
{
    m_aesKey = key;
    m_sendCounter = 0;
    m_recvCounter = 0;
    m_encrypted = true;
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

QByteArray UserConnection::makeIv(bool fromClient, quint64 counter)
{
    QByteArray iv(12, '\0');
    iv[0] = fromClient ? 0x00 : 0x01;
    for (int i = 0; i < 8; i++) {
        iv[11 - i] = static_cast<char>((counter >> (8 * i)) & 0xFF);
    }
    return iv;
}

QByteArray UserConnection::makeEnvelope(const QCborArray &body)
{
    QByteArray msg = body.toCborValue().toCbor();
    int flag = 0;
    if (msg.size() > COMPRESSION_THRESHOLD) {
        msg = qCompress(msg);
        flag |= DataCompressed;
    }
    if (m_encrypted) {
        msg = encryptData(msg, flag);
    }
    QCborArray envelope{flag, msg};
    return envelope.toCborValue().toCbor();
}

QByteArray UserConnection::encryptData(const QByteArray &data, int &flag)
{
    const QByteArray iv = makeIv(m_clientSide, m_sendCounter++);
    flag |= DataEncrypted;
    return aesGcmEncrypt(m_aesKey, iv, data);
}

QByteArray UserConnection::decryptData(const QByteArray &data)
{
    const QByteArray iv = makeIv(!m_clientSide, m_recvCounter++);
    return aesGcmDecrypt(m_aesKey, iv, data);
}

int UserConnection::request(const QByteArray &command, const QByteArray &jsonData, int timeout, qint64 timestamp, ReplyCallback callback)
{
    const int id = nextRequestId();
    int type = UserConnection::TypeRequest;
    if (timestamp <= 0) {
        timestamp = QDateTime::currentDateTime().toMSecsSinceEpoch();
    }
    QCborArray body{id, type, command, jsonData, timeout, timestamp};
    QByteArray msg = makeEnvelope(body);

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
    int type = TypeReply;
    if (ok) {
        type |= ReplyOk;
    } else {
        type |= ReplyError;
    }

    QCborArray body{requestId, type, QByteArray(), jsonData};

    sendMessage(makeEnvelope(body));
    m_receivedRequests.remove(requestId);
}

void UserConnection::notify(const QByteArray &command, const QByteArray &jsonData)
{
    int type = TypeNotification;

    QCborArray body{-2, type, command, jsonData};

    sendMessage(makeEnvelope(body));
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
    if (packet.size() < 2)
        return;

    const int flag = packet[0].toInteger();
    QByteArray payload = packet[1].toByteArray();

    if (flag & DataEncrypted) {
        payload = decryptData(payload);
        if (payload.isEmpty()) {
            if (m_socket && m_socket->socket()) {
                m_socket->socket()->disconnectFromHost();
            }
            return;
        }
    }

    if (flag & DataCompressed) {
        payload = qUncompress(payload);
    }

    const QCborValue inner = QCborValue::fromCbor(payload);
    if (!inner.isArray())
        return;

    const QCborArray body = inner.toArray();
    if (body.size() < 4)
        return;

    int requestId = body[0].toInteger();
    int type = body[1].toInteger();
    auto command = body[2].toByteArray();
    auto jsonData = body[3].toByteArray();

    if (type & TypeNotification) {
        Q_EMIT notificationGot(command, jsonData);
    } else if (type & TypeRequest) {
        ReceivedRequest rr{requestId, command, jsonData, int(body[4].toInteger()), body[5].toInteger()};
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
