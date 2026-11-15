#!/usr/bin/env bash
# pve-health.sh - one-screen health snapshot for a Proxmox VE node, with simple thresholds.
#
# Checks memory, swap, load per CPU, root disk, cluster quorum and the largest VMs by
# configured RAM (the usual cause of host memory pressure when ballooning is off).
# Quorum and VM checks are skipped on machines that are not Proxmox nodes.
#
# Usage: pve-health.sh [-m MEM_PCT] [-s SWAP_PCT] [-l LOAD_PER_CPU] [-d DISK_PCT]
# Exit codes: 0 all within thresholds, 1 at least one warning.
set -uo pipefail

mem_max=90; swap_max=50; load_max=1.5; disk_max=85
while getopts "m:s:l:d:h" opt; do
  case "$opt" in
    m) mem_max=$OPTARG ;; s) swap_max=$OPTARG ;; l) load_max=$OPTARG ;; d) disk_max=$OPTARG ;;
    h) sed -n '2,8p' "$0"; exit 0 ;; *) exit 2 ;;
  esac
done

warn=0
line() { printf '%-6s %-22s %s\n' "$1" "$2" "$3"; [[ $1 == WARN ]] && warn=1; return 0; }
pct() { awk -v a="$1" -v b="$2" 'BEGIN { if (b == 0) print 0; else printf "%.0f", a * 100 / b }'; }

read -r mem_total mem_avail swap_total swap_free < <(awk '
  /^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} /^SwapTotal:/ {st=$2} /^SwapFree:/ {sf=$2}
  END {print t, a, st, sf}' /proc/meminfo)
mem_pct=$(pct $((mem_total - mem_avail)) "$mem_total")
swap_pct=$(pct $((swap_total - swap_free)) "$swap_total")
(( mem_pct > mem_max )) && s=WARN || s=OK
line "$s" "memory used" "${mem_pct}% of $((mem_total / 1024 / 1024)) GiB (limit ${mem_max}%)"
(( swap_pct > swap_max )) && s=WARN || s=OK
line "$s" "swap used" "${swap_pct}% of $((swap_total / 1024 / 1024)) GiB (limit ${swap_max}%)"

cpus=$(nproc)
load1=$(cut -d' ' -f1 /proc/loadavg)
per_cpu=$(awk -v l="$load1" -v c="$cpus" 'BEGIN {printf "%.2f", l / c}')
awk -v p="$per_cpu" -v m="$load_max" 'BEGIN {exit !(p > m)}' && s=WARN || s=OK
line "$s" "load (1 min) per CPU" "$per_cpu on $cpus CPUs (limit $load_max)"

disk_pct=$(df --output=pcent / | tail -1 | tr -dc '0-9')
(( disk_pct > disk_max )) && s=WARN || s=OK
line "$s" "root filesystem" "${disk_pct}% used (limit ${disk_max}%)"

if command -v pvecm >/dev/null 2>&1; then
  if pvecm status 2>/dev/null | grep -q '^Quorate:[[:space:]]*Yes'; then
    votes=$(pvecm status 2>/dev/null | awk -F: '/Total votes/ {gsub(/ /,"",$2); print $2}')
    line OK "cluster quorum" "quorate (${votes:-?} votes)"
  else
    line WARN "cluster quorum" "NOT quorate or no cluster"
  fi
  echo
  echo "Largest VMs by configured memory (balloon minimum shown when set):"
  for conf in /etc/pve/qemu-server/*.conf; do
    [[ -e $conf ]] || continue
    id=$(basename "$conf" .conf)
    m=$(awk -F': ' '/^memory:/ {print $2}' "$conf"); b=$(awk -F': ' '/^balloon:/ {print $2}' "$conf")
    printf '  %-6s %6s MiB  balloon=%s\n' "$id" "${m:-512}" "${b:-off}"
  done | sort -k2 -nr | head -5
else
  line SKIP "cluster quorum" "not a Proxmox node"
fi

exit $warn
