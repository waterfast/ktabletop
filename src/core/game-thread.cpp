// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "game-thread.h"
#include "server.h"

#include "common-lua.h"
#include "lua/lua-binding.h"
#include "lua/lua-helper.h"
#include "server-lua.h"

#include <QEventLoop>

using namespace Qt::Literals::StringLiterals;

static int nextGameThreadId = 1;

GameThread::GameThread(Server *parent)
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
    connect(L, &LuaBinding::luaWarning, qobject_cast<Server *>(parent()), &Server::luaWarning);
    luaopen_ktabletop_common(L->state());
    luaopen_ktabletop_gamethread(L->state());
    L->setRuntimePaths(Server::instance()->luaBinding()->runtimePaths());
    L->run();

    // TODO: seems overused luaEvent. maybe should give this a new name to post some events to main thread Lua
    connect(L, &LuaBinding::luaEvent, Server::instance(), &Server::dispatchLuaEvent, Qt::UniqueConnection);

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
            LuaVM::call(L->state(), func, args);
        },
        Qt::QueuedConnection);
}

void GameThread::pushRequest(int roomId, int userId, const QString &command, const QVariantMap &data)
{
    call(u"HandleRequest"_s, {roomId, userId, command, data});
}
