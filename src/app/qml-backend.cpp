// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "qml-backend.h"
#include "client.h"
#include "lua-binding.h"
#include "server.h"

using namespace Qt::Literals::StringLiterals;

bool QmlBackend::startServer(ushort port)
{
    auto server = Server::instance();
    if (!server->listen(QHostAddress::Any, port)) {
        server->deleteLater();
        qCritical("Cannot start server!");
        return false;
    }
    return true;
}

void QmlBackend::joinServer(QString address, ushort port)
{
    auto client = Client::instance();
    connect(client->luaBinding(), &LuaBinding::luaEvent, this, &QmlBackend::luaEvent, Qt::UniqueConnection);
    client->connectToHost(address, port);
}

QQmlPropertyMap *QmlBackend::createPropertyMap(const QString &objectName, const QVariantMap &dict)
{
    if (auto existing = m_propertyMaps.take(objectName)) {
        existing->deleteLater();
    }

    auto ret = QQmlPropertyMap::create(this);
    ret->setObjectName(objectName);

    for (auto i = dict.cbegin(), end = dict.cend(); i != end; ++i) {
        ret->insert(i.key(), i.value());
    }

    connect(ret, &QQmlPropertyMap::valueChanged, this, [objectName](const QString &key, const QVariant &value) {
        Client::instance()->luaBinding()->emit(u"KTableTopCpp::ObservingObject::ValueChanged"_s,
                                               {
                                                   {u"_stringId"_s, objectName},
                                                   {u"key"_s, key},
                                                   {u"value"_s, value},
                                               });
    });

    m_propertyMaps.insert(objectName, ret);
    return ret;
}

void QmlBackend::destroyPropertyMap(const QString &objectName)
{
    if (auto existing = m_propertyMaps.take(objectName)) {
        existing->deleteLater();
    }
}
