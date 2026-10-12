#include "stdin-adapter.h"

#include "3rdparty/linenoise.hpp"
#include "util.h"
#include <QDebug>
#include <QDir>
#include <QEventLoop>

using namespace Qt::Literals::StringLiterals;

class StdinReader : public QObject
{
    Q_OBJECT
public:
    void run();

Q_SIGNALS:
    void lineReady(QString line);
};

void StdinReader::run()
{
    static constexpr auto welcomeMessage = R"(Welcome to KTabletop server side REPL interface.
KTabletop, Copyright (C) 2026, GNU LGPL'd, by KDE Community.
This program comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it under
certain conditions; For more information visit <http://www.gnu.org/licenses>.

Press Ctrl-C to start new line, Ctrl-D on blank line to quit.)";

    const auto path = QDir(KTabletopUtils::runtimeDataDir()).filePath(u"repl-history.txt"_s).toStdString();
    linenoise::SetHistoryMaxLen(5000);
    linenoise::LoadHistory(path.c_str());

    qInfo().noquote() << welcomeMessage;

    while (true) {
        std::string line;
        auto res = linenoise::detail::edit_line("\x1b[32mktabletop\x1b[0m> ", line);

        if (res == linenoise::EditStatus::Cancel) {
            continue;
        }
        if (res != linenoise::EditStatus::Done) {
            break;
        }

        Q_EMIT lineReady(QString::fromStdString(line));

        linenoise::AddHistory(line.c_str());
        linenoise::SaveHistory(path.c_str());
    }

    qInfo("Good bye.");
}

#include "stdin-adapter.moc"

// -------------------------------------------------

StdinAdapter::StdinAdapter(QObject *parent)
    : QThread(parent)
{
    setObjectName("StdinThread");
}

StdinAdapter::~StdinAdapter()
{
    quit();
    wait();
}

void StdinAdapter::run()
{
    StdinReader reader;

    connect(&reader, &StdinReader::lineReady, this, [](QString s) {
        qDebug() << s;
    });
    Q_EMIT ready();

    reader.run();
}

void StdinAdapter::editHide()
{
    linenoise::HideLine();
}

void StdinAdapter::editShow()
{
    linenoise::ShowLine();
}
