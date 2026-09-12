// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "game-thread.h"

#include "ktabletop-lua.h"
#include "lua/c-wrapper.h"
#include "lua/lua-binding.h"

#include <QEventLoop>

using namespace Qt::Literals::StringLiterals;

static int nextGameThreadId = 1;

GameThread::GameThread(QObject *parent)
    : QThread(parent)
    , m_id(nextGameThreadId++)
    , m_capacity(DefaultCapacity)
{
    setObjectName(u"GameThread-%1"_s.arg(m_id));

    // Wait until the Lua VM is created in run()
    QEventLoop loop;
    connect(this, &GameThread::ready, &loop, &QEventLoop::quit);
    start();
    loop.exec();
}

GameThread::~GameThread()
{
    if (isRunning()) {
        quit();
        wait();
    }
    delete L;
}

void GameThread::run()
{
    L = new LuaBinding(nullptr, LuaBinding::GameThread);
    luaopen_ktabletop(L->state());
    L->run();

    Q_EMIT ready();
    exec();
}

int GameThread::id() const
{
    return m_id;
}

int GameThread::capacity() const
{
    return m_capacity;
}

bool GameThread::isFull() const
{
    return m_rooms.size() >= m_capacity;
}

void GameThread::addRoom(int roomId)
{
    m_rooms.append(roomId);
}

void GameThread::removeRoom(int roomId)
{
    m_rooms.removeOne(roomId);
}

const QList<int> &GameThread::rooms() const
{
    return m_rooms;
}

LuaBinding *GameThread::lua() const
{
    return L;
}

void GameThread::call(QString func, QVariantList args)
{
    if (!L) {
        return;
    }
    QMetaObject::invokeMethod(
        L,
        [this, func, args] {
            L->vm().call(func, args);
        },
        Qt::QueuedConnection);
}

void GameThread::pushRequest(int roomId, int userId, const QString &command, const QVariantMap &data)
{
    call(u"HandleRequest"_s, {roomId, userId, command, data});
}
