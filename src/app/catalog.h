// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "qml/abstract-catalog.h"

#include <QString>
#include <QUrl>
#include <memory>

namespace spiritless_po
{
class Catalog;
}

class Catalog : public AbstractCatalog
{
    Q_OBJECT

public:
    explicit Catalog(const QUrl &url, QObject *parent = nullptr);

    QString i18n(const QString &msg) const override;
    QString i18nc(const QString &ctx, const QString &msg) const override;
    QString i18np(const QString &singular, const QString &plural, int n) const override;
    QString i18ncp(const QString &ctx, const QString &singular, const QString &plural, int n) const override;

private:
    std::shared_ptr<spiritless_po::Catalog> m_catalog;
};
