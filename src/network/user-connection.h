// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QPromise>

#include <functional>
#include <system_error>

#include <openssl/evp.h>

class ClientSocket;

class UserConnection : public QObject
{
    Q_OBJECT

public:
    enum PacketType {
        DataCompressed = 0x1000,
        DataEncrypted = 0x2000,

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

    void setAuthEphemeralKey(EVP_PKEY *key);
    EVP_PKEY *takeAuthEphemeralKey();

    void setAuthNonce(const QByteArray &nonce);
    QByteArray authNonce() const;

    void setPeerEphPublicKey(const QByteArray &key);
    QByteArray peerEphPublicKey() const;

    void setClientSide(bool clientSide);
    void enableEncryption(const QByteArray &key);

Q_SIGNALS:
    void messageReady(const QByteArray &msg);

    void notificationGot(const QByteArray &command, const QByteArray &jsonData);
    void requestGot(int requestId);
    void disconnected();

protected:
    void handlePacket(const QCborArray &packet);

private:
    // Sending side
    using RequestResult = std::pair<std::error_code, QByteArray>;
    QHash<int, std::shared_ptr<QPromise<RequestResult>>> m_pendingRequests;
    QMutex m_pendingRequestLock;

    // Receiving side
    QHash<int, ReceivedRequest> m_receivedRequests;

    ClientSocket *m_socket = nullptr;
    int m_connId;

    EVP_PKEY *m_authEphemeralKey = nullptr;
    QByteArray m_authNonce;
    QByteArray m_peerEphPublicKey;
    QByteArray m_aesKey;
    bool m_encrypted = false;
    bool m_clientSide = false;
    quint64 m_sendCounter = 0;
    quint64 m_recvCounter = 0;

    enum {
        COMPRESSION_THRESHOLD = 2048
    };

    void sendMessage(const QByteArray &msg);

    static QByteArray makeIv(bool fromClient, quint64 counter);
    QByteArray encryptData(const QByteArray &data, int &type);
    QByteArray decryptData(const QByteArray &data);

    static int nextRequestId();
};

Q_DECLARE_METATYPE(UserConnection::ReplyCallback)
