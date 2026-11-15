#!/usr/bin/env bash
# cert-expiry.sh - report TLS certificate expiry for a list of hosts and flag any expiring soon.
#
# Usage: cert-expiry.sh [-w WARN_DAYS] host[:port] [host[:port] ...]
#        cert-expiry.sh [-w WARN_DAYS] -f hosts.txt      (one host[:port] per line, # comments ok)
# Exit codes: 0 all fine, 1 at least one expiring/expired/unreachable, 2 usage error.
set -euo pipefail

warn_days=21
hosts=()
while getopts "w:f:h" opt; do
  case "$opt" in
    w) warn_days=$OPTARG ;;
    f) while IFS= read -r line; do
         line=${line%%#*}; line=${line//[[:space:]]/}
         [[ -n $line ]] && hosts+=("$line")
       done < "$OPTARG" ;;
    h) sed -n '2,6p' "$0"; exit 0 ;;
    *) exit 2 ;;
  esac
done
shift $((OPTIND - 1))
hosts+=("$@")
(( ${#hosts[@]} )) || { sed -n '4,5p' "$0" >&2; exit 2; }

now=$(date +%s)
bad=0
printf '%-40s %-9s %-6s %s\n' "HOST" "STATUS" "DAYS" "EXPIRES (UTC)"
for entry in "${hosts[@]}"; do
  host=${entry%%:*}; port=443
  [[ $entry == *:* ]] && port=${entry##*:}
  # -servername sends SNI, so hosts behind a shared proxy or CDN return the right certificate.
  if ! enddate=$(echo | timeout 10 openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null \
                 | openssl x509 -noout -enddate 2>/dev/null); then
    printf '%-40s %-9s %-6s %s\n' "$entry" "NO-CERT" "-" "unreachable or no TLS"; bad=1; continue
  fi
  enddate=${enddate#notAfter=}
  exp=$(date -d "$enddate" +%s)
  days=$(( (exp - now) / 86400 ))
  status=OK
  (( days < warn_days )) && status=WARN
  (( days < 0 )) && status=EXPIRED
  [[ $status != OK ]] && bad=1
  printf '%-40s %-9s %-6s %s\n' "$entry" "$status" "$days" "$(date -u -d "$enddate" '+%Y-%m-%d %H:%M')"
done
exit $bad
