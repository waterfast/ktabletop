// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>
#include <QtQml>

// Unified view model for pages before logging into a server.
// Since not Lua VM created this time, the view model must live in C++
class MainViewModel : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(MainViewModel)

    Q_PROPERTY(bool connected READ connected WRITE setConnected NOTIFY connectedChanged)
    Q_PROPERTY(int roomId READ roomId WRITE setRoomId NOTIFY roomIdChanged)
    Q_PROPERTY(bool gameStarted READ gameStarted WRITE setGameStarted NOTIFY gameStartedChanged)

public:
    explicit MainViewModel(QObject *parent = nullptr);

    bool connected() const;
    void setConnected(bool connected);

    int roomId() const;
    void setRoomId(int roomId);

    bool gameStarted() const;
    void setGameStarted(bool gameStarted);

    Q_INVOKABLE void startSinglePlayer();
    Q_INVOKABLE void startMultiPlayer();

Q_SIGNALS:
    void connectedChanged(bool connected);
    void roomIdChanged(int roomId);
    void gameStartedChanged(bool gameStarted);

    void startServerRequested(ushort port);
    void joinServerRequested(const QString &address, ushort port);

private:
    bool m_connected = false;
    int m_roomId = 0;
    bool m_gameStarted = false;
    QString m_host;
    int m_port = 17943;
};
