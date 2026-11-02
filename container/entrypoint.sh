#!/bin/sh
set -eu

uid="${HC_UID:-1000}"
gid="${HC_GID:-1000}"

case "$uid:$gid" in
  *[!0-9:]*|:*|*:) echo "Invalid container UID/GID" >&2; exit 2 ;;
esac

if [ "$(id -u)" -eq 0 ]; then
  if [ "$uid" != 0 ]; then
    if [ "$(id -u agent)" != "$uid" ]; then
      usermod -u "$uid" agent
    fi
    if getent group "$gid" >/dev/null; then
      usermod -g "$gid" agent
    elif [ "$(id -g agent)" != "$gid" ]; then
      groupmod -g "$gid" agent
    fi
  fi
  chown "$uid:$gid" /home/agent /home/agent/.config /home/agent/.local /home/agent/.local/share
  exec gosu "$uid:$gid" /usr/local/bin/harness-launch "$@"
fi

exec /usr/local/bin/harness-launch "$@"
