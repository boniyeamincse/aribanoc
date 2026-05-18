#!/bin/sh
# Zabbix alert script: send Telegram notification
# Place in /usr/lib/zabbix/alertscripts/telegram.sh
# Zabbix media type: Script; Parameters: {SEND_TO} {SUBJECT} {MESSAGE}
set -eu

TO="$1"        # Telegram chat_id (from Zabbix user media configuration)
SUBJECT="$2"
MESSAGE="$3"

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"

if [ -z "$BOT_TOKEN" ]; then
  echo "ERROR: TELEGRAM_BOT_TOKEN not set" >&2
  exit 1
fi

TEXT="$(printf '*%s*\n%s' "$SUBJECT" "$MESSAGE")"

curl -sSf "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="$TO" \
  -d parse_mode="Markdown" \
  --data-urlencode text="$TEXT" \
  -o /dev/null

exit 0
