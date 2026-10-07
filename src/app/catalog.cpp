// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "catalog.h"
#include "client.h"
#include "lua/lua-binding.h"

#include "3rdparty/spiritless_po.h"

#include <KLocalizedString>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>

#include <exception>
#include <sstream>

using namespace Qt::Literals::StringLiterals;

// cache of catalogs: full path -> catalog
static QHash<QString, std::weak_ptr<spiritless_po::Catalog>> s_catalogs;

Catalog::Catalog(const QUrl &url, QObject *parent)
    : AbstractCatalog(parent)
{
    if (!url.isLocalFile() || !Client::initialized()) {
        return;
    }

    const QString path = QDir::cleanPath(url.toLocalFile());

    QString pluginRoot;
    const QStringList pluginPaths = Client::instance()->luaBinding()->runtimePaths();
    for (const QString &root : pluginPaths) {
        if ((path == root || path.startsWith(root + u'/')) && root.size() > pluginRoot.size()) {
            pluginRoot = root;
        }
    }
    if (pluginRoot.isEmpty()) {
        return;
    }

    const QString domain = u"ktabletop-plugin-%1"_s.arg(QFileInfo(pluginRoot).fileName());
    const QString localeDir = pluginRoot + u"/i18n"_s;

    const QStringList languages = KLocalizedString::languages();
    const QString key = pluginRoot + u'\n' + languages.join(u'\n');

    if (auto cached = s_catalogs.value(key).lock()) {
        m_catalog = cached;
        return;
    }

    s_catalogs.removeIf([](const auto &it) {
        return it.value().expired();
    });

    auto catalog = std::make_shared<spiritless_po::Catalog>();
    for (const QString &lang : languages) {
        QFile file(localeDir + u'/' + lang + u'/' + domain + u".po"_s);
        if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
            continue;
        }
        const QByteArray data = file.readAll();
        std::istringstream stream(data.toStdString());
        try {
            catalog->Add(stream);
        } catch (const std::exception &e) {
            qWarning() << "Catalog: failed to parse" << file.fileName() << e.what();
            continue;
        } catch (...) {
            qWarning() << "Catalog: failed to parse" << file.fileName();
            continue;
        }
        for (const std::string &error : catalog->GetError()) {
            qWarning() << "Catalog: PO parse error in" << file.fileName() << QString::fromStdString(error);
        }
        catalog->ClearError();
    }

    m_catalog = catalog;
    s_catalogs.insert(key, catalog);
}

QString Catalog::i18n(const QString &msg) const
{
    return m_catalog ? QString::fromStdString(m_catalog->gettext(msg.toStdString())) : msg;
}

QString Catalog::i18nc(const QString &ctx, const QString &msg) const
{
    return m_catalog ? QString::fromStdString(m_catalog->pgettext(ctx.toStdString(), msg.toStdString())) : msg;
}

QString Catalog::i18np(const QString &singular, const QString &plural, int n) const
{
    return m_catalog ? QString::fromStdString(m_catalog->ngettext(singular.toStdString(), plural.toStdString(), static_cast<unsigned long>(n)))
                     : (n == 1 ? singular : plural);
}

QString Catalog::i18ncp(const QString &ctx, const QString &singular, const QString &plural, int n) const
{
    return m_catalog
        ? QString::fromStdString(m_catalog->npgettext(ctx.toStdString(), singular.toStdString(), plural.toStdString(), static_cast<unsigned long>(n)))
        : (n == 1 ? singular : plural);
}
