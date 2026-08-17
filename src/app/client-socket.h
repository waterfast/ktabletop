// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QCborError>
#include <QTcpSocket>
#include <QTimer>

class ClientSocket : public QObject
{
    Q_OBJECT

public:
    ClientSocket();
    ClientSocket(QTcpSocket *socket);
    ~ClientSocket();

    QTcpSocket *socket() const;
    void send(const QByteArray &msg);
    QTimer timerSignup;

Q_SIGNALS:
    void messageGot(const QCborArray &msg);
    void errorMessage(const QString &msg);

private Q_SLOTS:
    void getMessage();
    void raiseError(QAbstractSocket::SocketError error);

private:
    void init();

    QTcpSocket *socket_;

    QByteArray cborBuffer;

    QList<QCborArray> readCborArrsFromBuffer(QCborError *err);
};
