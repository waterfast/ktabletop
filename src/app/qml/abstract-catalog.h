// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>
#include <QString>

class AbstractCatalog : public QObject
{
    Q_OBJECT

public:
    explicit AbstractCatalog(QObject *parent = nullptr);
    ~AbstractCatalog() override;

    virtual QString i18n(const QString &msg) const;
    virtual QString i18nc(const QString &ctx, const QString &msg) const;
    virtual QString i18np(const QString &singular, const QString &plural, int n) const;
    virtual QString i18ncp(const QString &ctx, const QString &singular, const QString &plural, int n) const;
};
