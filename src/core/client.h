// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>

class LuaBinding;
class UserConnection;

class Client : public QObject
{
    Q_OBJECT

public:
    static Client *instance();
    static bool initialized();
    static void destroy();
    ~Client();

    LuaBinding *luaBinding() const;
    UserConnection *connection() const;

    void connectToHost(const QString &server, ushort port = 17943, const QString &username = QString(), const QString &password = QString());

    void setTaskStatus(const QString &key, const QString &message, int progress, bool cancelable = false, std::function<void()> cancelFn = {});
    void completeTask(const QString &key);

Q_SIGNALS:
    void showToast(const QString &message);
    void showErrorDialog(const QString &message);
    void setProgressDialogData(const QString &key, const QString &message, int progress, bool cancelable);

private:
    explicit Client(QObject *parent = nullptr);

    LuaBinding *L;
    UserConnection *m_connection;
};
