// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QThread>
#include <QVariantList>

class LuaBinding;

// Thread for running game logic Lua VM
class GameThread : public QThread
{
    Q_OBJECT

public:
    static constexpr int DefaultCapacity = 2000;

    explicit GameThread(QObject *parent = nullptr);
    ~GameThread() override;

    int id() const;
    int capacity() const;

    bool isFull() const;

    void addRoom(int roomId);
    void removeRoom(int roomId);
    const QList<int> &rooms() const;

    LuaBinding *lua() const;

    // call something inside this thread.
    void call(QString func, QVariantList args = {});

Q_SIGNALS:
    void ready();

protected:
    void run() override;

private:
    int id_;
    int capacity_;
    QList<int> rooms_;

    LuaBinding *L = nullptr;
};
