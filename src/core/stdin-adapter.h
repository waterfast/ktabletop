#pragma once

#include <QObject>
#include <QThread>

class StdinAdapter : public QThread
{
    Q_OBJECT

public:
    StdinAdapter(QObject *parent = nullptr);
    ~StdinAdapter();

    void editHide();
    void editShow();

Q_SIGNALS:
    void commandReady(QString command, QVariantMap data);

protected:
    void run() override;

private:
    Q_SIGNAL void ready();
};
