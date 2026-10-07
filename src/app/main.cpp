// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include <KirigamiApp>
#include <QtGlobal>

#ifdef Q_OS_ANDROID
#include <QGuiApplication>
#else
#include <QApplication>
#endif
#include <QCommandLineParser>
#include <QIcon>
#include <QQmlApplicationEngine>

#include <KAboutData>
#include <KLocalizedQmlContext>
#include <KLocalizedString>
#include <KirigamiAppDefaults>

#include <QDir>
#include <QThread>

#include "catalog.h"
#include "core/logger.h"
#include "qml-backend-controller.h"
#include "qml/qml-backend.h"

using namespace Qt::Literals::StringLiterals;

#ifdef Q_OS_ANDROID
Q_DECL_EXPORT
#endif
int main(int argc, char *argv[])
{
    QThread::currentThread()->setObjectName(QStringLiteral("Main"));

    initLogger();
    installQtMessageHandler();

#ifdef Q_OS_ANDROID
    QGuiApplication app(argc, argv);
#else
    QApplication app(argc, argv);
#endif
    KirigamiAppDefaults::apply(&app);

    KLocalizedString::setApplicationDomain("ktabletop");

    KAboutData aboutData(u"ktabletop"_s,
                         i18n("KTabletop"),
                         QStringLiteral("0.0.1"),
                         i18n("Play boardgames online"),
                         KAboutLicense::LGPL_V2_1,
                         i18n("© 2026 KDE Community"));
    aboutData.addAuthor(i18n("notify-ctrl"),
                        i18n("Maintainer"),
                        u"notify-ctrl@qq.com"_s,
                        u"https://notify-ctrl.netlify.app/"_s,
                        QUrl(u"https://notify-ctrl.netlify.app/images/avatar.jpg"_s));
    aboutData.setTranslator(i18nc("NAME OF TRANSLATORS", "Your names"), i18nc("EMAIL OF TRANSLATORS", "Your emails"));
    KAboutData::setApplicationData(aboutData);
    QGuiApplication::setWindowIcon(QIcon::fromTheme(u"org.kde.ktabletop"_s));

    QQmlApplicationEngine engine;

    KLocalization::setupLocalizedContext(&engine);

    {
        QCommandLineParser parser;
        aboutData.setupCommandLine(&parser);
        parser.process(app);
        aboutData.processCommandLine(&parser);
    }

    engine.loadFromModule("org.kde.ktabletop", u"Main"_s);
    if (engine.rootObjects().isEmpty()) {
        return EXIT_FAILURE;
    }

    auto *backend = engine.singletonInstance<QmlBackend *>("org.kde.ktabletop", "Backend");
    backend->setCatalogFactory([](const QUrl &url, QObject *parent) {
        return new Catalog(url, parent);
    });

    QmlBackendController controller(backend);

    return app.exec();
}
