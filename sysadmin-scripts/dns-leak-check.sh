#!/usr/bin/env bash
# dns-leak-check.sh - check that a VPN-only host or user does not resolve names through the LAN.
#
# Run it as the user whose traffic must stay in the tunnel (for example: sudo -u appuser ./dns-leak-check.sh ...).
# It checks three things:
#   1. resolv.conf lists only the resolvers you allow (normally the VPN provider's DNS)
#   2. the LAN resolver is NOT reachable on port 53 (it should be blocked for this user)
#   3. the public IP seen from outside matches the VPN exit, not the home connection
#
# Usage: dns-leak-check.sh -a "ALLOWED_RESOLVER ..." -l LAN_RESOLVER [-v EXPECTED_VPN_IP_PREFIX]
# Exit codes: 0 no leak found, 1 leak or misconfiguration found, 2 usage error.
set -uo pipefail

allowed=""; lan=""; vpn_prefix=""
while getopts "a:l:v:h" opt; do
  case "$opt" in
    a) allowed=$OPTARG ;;
    l) lan=$OPTARG ;;
    v) vpn_prefix=$OPTARG ;;
    h) sed -n '2,11p' "$0"; exit 0 ;;
    *) exit 2 ;;
  esac
done
[[ -n $allowed && -n $lan ]] || { sed -n '10p' "$0" >&2; exit 2; }
command -v dig >/dev/null || { echo "ERROR: dig not installed (dnsutils / bind-utils)" >&2; exit 2; }

fail=0
pass() { printf 'PASS  %s\n' "$*"; }
bad()  { printf 'FAIL  %s\n' "$*"; fail=1; }

# 1. Configured resolvers
mapfile -t servers < <(awk '/^nameserver/ {print $2}' /etc/resolv.conf)
(( ${#servers[@]} )) || bad "no nameserver lines in /etc/resolv.conf"
for s in "${servers[@]}"; do
  if [[ " $allowed " == *" $s "* ]]; then pass "resolv.conf uses allowed resolver $s"
  else bad "resolv.conf lists $s, which is not in the allowed list"; fi
done
if grep -qE '^(search|domain)[[:space:]]' /etc/resolv.conf; then
  bad "resolv.conf has a search/domain line (names may be retried with the local domain appended)"
else
  pass "no search/domain suffix in resolv.conf"
fi

# 2. LAN resolver must not answer for this user
if dig +time=2 +tries=1 +short @"$lan" example.com A >/dev/null 2>&1 \
   && [[ -n $(dig +time=2 +tries=1 +short @"$lan" example.com A 2>/dev/null) ]]; then
  bad "LAN resolver $lan answered; DNS can leave outside the tunnel"
else
  pass "LAN resolver $lan is not reachable from here"
fi

# 3. Public egress IP, as seen by an outside resolver (asked through the allowed path)
egress=$(dig +time=3 +tries=1 +short TXT o-o.myaddr.l.google.com @ns1.google.com 2>/dev/null | tr -d '"')
if [[ -z $egress ]]; then
  bad "could not determine the public egress IP"
elif [[ -n $vpn_prefix && $egress != "$vpn_prefix"* ]]; then
  bad "egress IP $egress does not match the expected VPN prefix $vpn_prefix"
else
  pass "egress IP is $egress${vpn_prefix:+ (matches VPN prefix)}"
fi

exit $fail
