# prime-uptime

Сторож домашнего сервера: каждые 5 минут GitHub Actions открывает сайты на prime-home
(`check.sh`), при смене состояния пишет в Telegram (@prime_server_status_bot).

Секреты репозитория: `TG_TOKEN` — токен бота, `TG_CHAT` — chat id.
Проверить вручную: Actions → uptime → Run workflow.
