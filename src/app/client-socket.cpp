// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client-socket.h"
#include <QCborArray>
#include <QCborStreamReader>
#include <QCborValue>

#include <QStringLiteral>
using namespace Qt::Literals::StringLiterals;

ClientSocket::ClientSocket()
    : socket_(new QTcpSocket(this))
{
    init();
}

ClientSocket::ClientSocket(QTcpSocket *socket)
{
    socket->setParent(this);
    this->socket_ = socket;
    // timerSignup.setSingleShot(true);
    // connect(&timerSignup, &QTimer::timeout, this,
    //         &ClientSocket::disconnectFromHost);
    // connect(&timerSignup, &QTimer::timeout, this, &QObject::deleteLater);
    init();
}

ClientSocket::~ClientSocket()
{
}

void ClientSocket::init()
{
    connect(socket_, &QTcpSocket::readyRead, this, &ClientSocket::getMessage);
    connect(socket_, &QTcpSocket::errorOccurred, this, &ClientSocket::raiseError);
    socket_->setSocketOption(QAbstractSocket::KeepAliveOption, 1);
}

void ClientSocket::getMessage()
{
    cborBuffer += socket_->readAll();
    QCborError err;
    auto arr = readCborArrsFromBuffer(&err);
    if (err == QCborError::EndOfFile || err == QCborError::NoError) {
        for (auto &a : arr)
            messageGot(a);
        return;
    } else {
        socket_->disconnectFromHost();
        return;
    }
}

QTcpSocket *ClientSocket::socket() const
{
    return socket_;
}

void ClientSocket::send(const QByteArray &msg)
{
    if (socket_->state() != QTcpSocket::ConnectedState) {
        errorMessage(u"Cannot send messages if not connected"_s);
        return;
    }

    socket_->write(msg);
    socket_->flush();
}

void ClientSocket::raiseError(QAbstractSocket::SocketError socket_error)
{
    QString reason;
    switch (socket_error) {
    case QAbstractSocket::ConnectionRefusedError:
        reason = tr("Connection was refused or timeout");
        break;
    case QAbstractSocket::RemoteHostClosedError:
        reason = tr("Remote host close this connection");
        break;
    case QAbstractSocket::HostNotFoundError:
        reason = tr("Host not found");
        break;
    case QAbstractSocket::SocketAccessError:
        reason = tr("Socket access error");
        break;
    case QAbstractSocket::SocketResourceError:
        reason = tr("Socket resource error");
        break;
    case QAbstractSocket::SocketTimeoutError:
        reason = tr("Socket timeout error");
        break;
    case QAbstractSocket::DatagramTooLargeError:
        reason = tr("Datagram too large error");
        break;
    case QAbstractSocket::NetworkError:
        reason = tr("Network error");
        break;
    case QAbstractSocket::UnsupportedSocketOperationError:
        reason = tr("Unsupprted socket operation");
        break;
    case QAbstractSocket::UnfinishedSocketOperationError:
        reason = tr("Unfinished socket operation");
        break;
    case QAbstractSocket::ProxyAuthenticationRequiredError:
        reason = tr("Proxy auth error");
        break;
    case QAbstractSocket::ProxyConnectionRefusedError:
        reason = tr("Proxy refused");
        break;
    case QAbstractSocket::ProxyConnectionClosedError:
        reason = tr("Proxy closed");
        break;
    case QAbstractSocket::ProxyConnectionTimeoutError:
        reason = tr("Proxy timeout");
        break;
    case QAbstractSocket::ProxyProtocolError:
        reason = tr("Proxy protocol error");
        break;
    case QAbstractSocket::OperationError:
        reason = tr("Operation error");
        break;
    case QAbstractSocket::TemporaryError:
        reason = tr("Temporary error");
        break;
    default:
        reason = tr("Unknown error");
        break;
    }

    errorMessage(tr("Connection failed, error code = %1\n reason: %2").arg(socket_error).arg(reason));
}

static QCborValue readItem(QCborStreamReader &reader)
{
    switch (reader.type()) {
    case QCborStreamReader::UnsignedInteger:
    case QCborStreamReader::NegativeInteger: {
        auto val = reader.toInteger();
        reader.next();
        return val;
    }
    case QCborStreamReader::ByteArray: {
        QByteArray ret;
        auto r = reader.readByteArray();
        while (r.status == QCborStreamReader::Ok) {
            ret += r.data;
            r = reader.readByteArray();
        }

        if (r.status == QCborStreamReader::Error) {
            // handle error condition
            ret.clear();
        }
        return ret;
    }
    case QCborStreamReader::Array: {
        QCborArray arr;
        reader.enterContainer();
        while (reader.lastError() == QCborError::NoError && reader.hasNext()) {
            auto item = readItem(reader);
            if (item.isUndefined())
                break;
            arr << item;
        }
        if (reader.lastError() == QCborError::NoError)
            reader.leaveContainer();
        return arr;
    }
    default:
        break;
    }
    return QCborValue();
}

QList<QCborArray> ClientSocket::readCborArrsFromBuffer(QCborError *err)
{
    auto cbuf = cborBuffer.constData();
    auto len = cborBuffer.size();
    QList<QCborArray> ret;

    while (true) {
        QCborStreamReader reader(cbuf, len);
        auto item = readItem(reader);
        if (reader.lastError() != QCborError::NoError) {
            *err = reader.lastError();
            break;
        }
        if (!item.isArray())
            break;
        ret << item.toArray();
        auto off = reader.currentOffset();
        cbuf += off;
        len -= off;
    }

    cborBuffer = {cbuf, len};
    return ret;
}
