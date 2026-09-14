// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCoreApplication>
#include <QHostAddress>

#include "core/logger.h"
#include "core/server.h"

using namespace Qt::Literals::StringLiterals;

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(u"ktabletop-server"_s);
    QCoreApplication::setApplicationVersion(u"0.0.1"_s);

    initLogger();
    installQtMessageHandler();

    QCommandLineParser parser;
    parser.setApplicationDescription(u"KTabletop dedicated server"_s);
    parser.addHelpOption();
    parser.addVersionOption();
    QCommandLineOption portOption({u"p"_s, u"port"_s}, u"Port to listen on."_s, u"port"_s, QString::number(Server::DefaultPort));
    parser.addOption(portOption);
    parser.process(app);

    bool ok = false;
    const ushort port = parser.value(portOption).toUShort(&ok);
    if (!ok) {
        qCritical("Invalid port: %s", qPrintable(parser.value(portOption)));
        return EXIT_FAILURE;
    }

    if (!Server::instance()->listen(QHostAddress::Any, port)) {
        qCritical("Cannot start server on port %u!", port);
        return EXIT_FAILURE;
    }

    return app.exec();
}
