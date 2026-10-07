// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QMap>
#include <QObject>
#include <QUrl>
#include <QVariant>
#include <QtQml>

#include <functional>

class AbstractCatalog;
class LObjectProxy;
class MainViewModel;

class QmlBackend : public QObject
{
    Q_OBJECT
    QML_SINGLETON
    QML_NAMED_ELEMENT(Backend)

    Q_PROPERTY(MainViewModel *mainViewModel READ mainViewModel CONSTANT)

public:
    using CatalogFactory = std::function<AbstractCatalog *(const QUrl &url, QObject *parent)>;

    explicit QmlBackend(QObject *parent = nullptr);
    ~QmlBackend() override;

    MainViewModel *mainViewModel() const;

    void setCatalogFactory(CatalogFactory factory);
    AbstractCatalog *createCatalog(const QUrl &url, QObject *parent) const;

    Q_INVOKABLE LObjectProxy *getObservable(const QString &objectName) const;

    Q_INVOKABLE void emit(const QString &type, const QVariantMap &payload);

Q_SIGNALS:
    void enterLobby();

    // emitted from QML (via emit()), forwarded by the host to luaBinding->emit
    void emitRequested(const QString &type, const QVariantMap &payload);

private:
    MainViewModel *m_mainViewModel;
    CatalogFactory m_catalogFactory;
};
