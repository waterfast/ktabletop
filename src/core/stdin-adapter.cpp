#include "stdin-adapter.h"

#include "3rdparty/linenoise.hpp"
#include <QDebug>
#include <QEventLoop>

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
    const auto path = "./repl-history.txt";
    linenoise::SetHistoryMaxLen(5000);
    linenoise::LoadHistory(path);
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
        linenoise::SaveHistory(path);
    }

    qInfo("Good bye.");
}

#include "stdin-adapter.moc"

// -------------------------------------------------

StdinAdapter::StdinAdapter(QObject *parent)
    : QThread(parent)
{
    setObjectName("StdinThread");

    QEventLoop loop;
    connect(this, &StdinAdapter::ready, &loop, &QEventLoop::quit);
    start();
    loop.exec();
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
