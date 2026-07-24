#!/bin/sh
# Fail closed. The linuxserver image boots sshd even when our drop-in is ignored (wrong
# mount path, an image change to the include behaviour, etc.), silently falling back to
# insecure defaults. This asserts sshd's *effective* config (`sshd -T`) contains every
# directive from the mounted drop-in; on mismatch it exits non-zero so Kubernetes pulls
# the pod from the LoadBalancer (readiness) and restarts / crash-loops it (startup +
# liveness) instead of accepting connections with unintended settings.
#
# Expected directives are read from the drop-in itself, so this can never drift from the
# config we ship.
DROPIN=/config/sshd/sshd_config.d/100-ifrc-forwarding.conf
PORT=2222

# sshd must be accepting connections ...
nc -z 127.0.0.1 "$PORT" || exit 1

# ... pass the host keys explicitly (as the image's service does) so `sshd -T` works even
# when this probe runs as a non-root user (otherwise it exits "no hostkeys available").
h=""
for k in /config/ssh_host_keys/ssh_host_*_key; do
  [ -f "$k" ] && h="$h -h $k"
done

eff=$(sshd.pam -T -f /config/sshd/sshd_config $h 2>/dev/null | tr 'A-Z' 'a-z')

missing=$(grep -vE '^[[:space:]]*(#|$)' "$DROPIN" | tr 'A-Z' 'a-z' | while IFS= read -r line; do
  d=$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -n "$d" ] || continue
  printf '%s\n' "$eff" | grep -qF "$d" || printf '%s\n' "$d"
done)

if [ -n "$missing" ]; then
  echo "sshd config assertion FAILED (missing directives):" >&2
  printf '%s\n' "$missing" >&2
  exit 1
fi
