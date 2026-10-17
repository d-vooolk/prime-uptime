#!/usr/bin/env bash
# Проверяет сайты на домашнем сервере. Сообщение в Telegram — только при смене
# состояния (упал / поднялся), состояние хранится в state.txt в этом репозитории.
set -u

URLS=(
  https://crm.prime-auto.by/
  https://prime-auto.by/
  https://vdf.by/
)
ATTEMPTS=3   # сайт считается недоступным, если не ответил 3 раза подряд
PAUSE=30     # секунд между попытками

check_url() {
  local code
  for i in $(seq 1 "$ATTEMPTS"); do
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$1")
    [[ "$code" =~ ^[23] ]] && return 0
    [ "$i" -lt "$ATTEMPTS" ] && sleep "$PAUSE"
  done
  echo "$code"
  return 1
}

down=()
details=()
for url in "${URLS[@]}"; do
  if ! code=$(check_url "$url"); then
    down+=("$url")
    details+=("$url — ${code/000/нет ответа}")
  fi
done

new_state="up"
[ "${#down[@]}" -gt 0 ] && new_state="down: ${down[*]}"
old_state=$(cat state.txt 2>/dev/null || echo "up")
echo "было: $old_state"
echo "стало: $new_state"

send() {
  curl -s -o /dev/null -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TG_CHAT}" --data-urlencode "text=$1"
}

if [ "$new_state" != "$old_state" ]; then
  if [ "$new_state" = "up" ]; then
    send "🟢 Сайты prime-home снова открываются."
  elif [ "${#down[@]}" -eq "${#URLS[@]}" ]; then
    send "🔴 Сервер prime-home недоступен — не открывается ни один сайт (свет, интернет или сам сервер).
$(printf '%s\n' "${details[@]}")"
  else
    send "🟠 Не открываются сайты на prime-home:
$(printf '%s\n' "${details[@]}")"
  fi
  echo "$new_state" > state.txt
fi

# GitHub отключает расписание в репозитории без изменений 60 дней — раз в 30 дней отмечаемся
last=$(git log -1 --format=%ct 2>/dev/null || echo 0)
if [ $(( $(date +%s) - last )) -gt $(( 30 * 86400 )) ]; then
  date -u +%FT%TZ > keepalive.txt
fi

if [ -n "$(git status --porcelain)" ]; then
  git config user.name "uptime-bot"
  git config user.email "uptime-bot@users.noreply.github.com"
  git add -A && git commit -qm "состояние: $new_state" && git push -q
fi
