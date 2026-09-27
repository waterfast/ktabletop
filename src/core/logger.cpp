// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "logger.h"

#include "server.h"
#include "stdin-adapter.h"

#include <spdlog/pattern_formatter.h>
#include <spdlog/sinks/callback_sink.h>
#include <spdlog/sinks/rotating_file_sink.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/spdlog.h>

#include <QThread>

#include <chrono>
#include <string>
#include <string_view>
#include <vector>

class thread_name_flag : public spdlog::custom_flag_formatter
{
public:
    void format(const spdlog::details::log_msg &, const std::tm &, spdlog::memory_buf_t &dest) override
    {
        const auto name = QThread::currentThread()->objectName();
        if (name.isEmpty()) {
            return;
        }
        const auto nameBytes = name.toStdString();
        dest.append(std::string_view{nameBytes.data(), nameBytes.size()});
    }

    std::unique_ptr<custom_flag_formatter> clone() const override
    {
        return spdlog::details::make_unique<thread_name_flag>();
    }
};

void initLogger()
{
    constexpr auto logger_file = "ktabletop.log";

    std::vector<spdlog::sink_ptr> sinks;

    auto clearline_sink = std::make_shared<spdlog::sinks::callback_sink_mt>([](const spdlog::details::log_msg &) {
        if (!Server::initialized())
            return;
        auto *shell = Server::instance()->shell();
        shell->editHide();
    });
    sinks.push_back(clearline_sink);

    auto stdout_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
    auto formatter = std::make_unique<spdlog::pattern_formatter>();
    formatter->add_flag<thread_name_flag>('t').set_pattern("%C-%m-%d %H:%M:%S.%e %t[%^%L%$] %v");
    stdout_sink->set_formatter(std::move(formatter));
    stdout_sink->set_color_mode(spdlog::color_mode::always);
    sinks.push_back(stdout_sink);

    auto rotate_sink = std::make_shared<spdlog::sinks::rotating_file_sink_mt>(logger_file, 1048576 * 30, 5);
    formatter = std::make_unique<spdlog::pattern_formatter>();
    formatter->add_flag<thread_name_flag>('t').set_pattern("%C-%m-%d %H:%M:%S.%e %t[%L] %v");
    rotate_sink->set_formatter(std::move(formatter));
    sinks.push_back(rotate_sink);

    auto redisplay_sink = std::make_shared<spdlog::sinks::callback_sink_mt>([](const spdlog::details::log_msg &) {
        if (!Server::initialized())
            return;
        auto *shell = Server::instance()->shell();
        shell->editShow();
    });
    sinks.push_back(redisplay_sink);

    auto logger = std::make_shared<spdlog::logger>("ktabletop", sinks.begin(), sinks.end());
    spdlog::register_logger(logger);
    spdlog::set_default_logger(logger);
    spdlog::set_level(spdlog::level::trace);
    spdlog::flush_every(std::chrono::seconds(3));
}

static void qtMessageHandler(QtMsgType type, const QMessageLogContext &, const QString &msg)
{
    switch (type) {
    case QtDebugMsg:
        spdlog::debug(msg.toStdString());
        break;
    case QtInfoMsg:
        spdlog::info(msg.toStdString());
        break;
    case QtWarningMsg:
        spdlog::warn(msg.toStdString());
        break;
    case QtCriticalMsg:
        spdlog::critical(msg.toStdString());
        break;
    case QtFatalMsg:
        spdlog::error(msg.toStdString());
        break;
    }
}

void installQtMessageHandler()
{
    qInstallMessageHandler(qtMessageHandler);
}
