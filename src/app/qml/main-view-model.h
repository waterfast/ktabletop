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
    Q_PROPERTY(QString lobbyViewModelName READ lobbyViewModelName NOTIFY lobbyViewModelNameChanged)
    Q_PROPERTY(QString roomViewModelName READ roomViewModelName NOTIFY roomViewModelNameChanged)
    Q_PROPERTY(QString gameViewModelName READ gameViewModelName NOTIFY gameViewModelNameChanged)
    Q_PROPERTY(QString gamePageUrl READ gamePageUrl NOTIFY gamePageUrlChanged)
    Q_PROPERTY(bool gameStarted READ gameStarted WRITE setGameStarted NOTIFY gameStartedChanged)

public:
    explicit MainViewModel(QObject *parent = nullptr);

    bool connected() const;
    void setConnected(bool connected);

    int roomId() const;
    void setRoomId(int roomId);

    QString lobbyViewModelName() const;
    void setLobbyViewModelName(const QString &name);

    QString roomViewModelName() const;
    void setRoomViewModelName(const QString &name);

    QString gameViewModelName() const;
    void setGameViewModelName(const QString &name);

    QString gamePageUrl() const;
    void setGamePageUrl(const QString &url);

    bool gameStarted() const;
    void setGameStarted(bool gameStarted);

    Q_INVOKABLE void startSinglePlayer(const QString &username);
    Q_INVOKABLE void joinMultiPlayer(const QString &address, int port, const QString &username);

Q_SIGNALS:
    void connectedChanged(bool connected);
    void roomIdChanged(int roomId);
    void lobbyViewModelNameChanged(const QString &name);
    void roomViewModelNameChanged(const QString &name);
    void gameViewModelNameChanged(const QString &name);
    void gamePageUrlChanged(const QString &url);
    void gameStartedChanged(bool gameStarted);

    void startServerRequested(ushort port);
    void joinServerRequested(const QString &address, ushort port, const QString &username);

private:
    bool m_connected = false;
    int m_roomId = 0;
    QString m_lobbyViewModelName;
    QString m_roomViewModelName;
    QString m_gameViewModelName;
    QString m_gamePageUrl;
    bool m_gameStarted = false;
    QString m_host;
    int m_port = 17943;
};
