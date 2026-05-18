#!/bin/sh
# Zabbix alert script: send email notification via SMTP
# Place in /usr/lib/zabbix/alertscripts/email.sh
# Zabbix media type: Script; Parameters: {SEND_TO} {SUBJECT} {MESSAGE}
# Requires: curl with SMTP support (usually available in alpine-based images)
set -eu

TO="$1"
SUBJECT="$2"
BODY="$3"

SMTP_HOST="${ALERT_SMTP_HOST:-}"
SMTP_PORT="${ALERT_SMTP_PORT:-587}"
SMTP_USER="${ALERT_SMTP_USER:-}"
SMTP_PASS="${ALERT_SMTP_PASS:-}"
FROM="${ALERT_EMAIL_FROM:-noc@example.com}"

if [ -z "$SMTP_HOST" ] || [ -z "$SMTP_USER" ]; then
  echo "ERROR: SMTP not configured (ALERT_SMTP_HOST / ALERT_SMTP_USER)" >&2
  exit 1
fi

TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" << EOF
From: NOC Alerting <${FROM}>
To: ${TO}
Subject: ${SUBJECT}
Content-Type: text/plain; charset=UTF-8

${BODY}
EOF

curl -sSf \
  --url "smtp://${SMTP_HOST}:${SMTP_PORT}" \
  --ssl-reqd \
  --mail-from "$FROM" \
  --mail-rcpt "$TO" \
  --user "${SMTP_USER}:${SMTP_PASS}" \
  --upload-file "$TMPFILE" \
  -o /dev/null

exit 0
