#!/usr/bin/env bash
# pve-restore-test.sh - prove an LXC backup actually restores and boots, then throw the copy away.
#
# Restores the newest vzdump archive of a container to a temporary ID, cuts it off from
# every real network and bind mount BEFORE first boot, starts it, runs a health check
# inside it, then destroys the copy. Run as root on a Proxmox VE node (cron or by hand).
#
# Usage: pve-restore-test.sh -c CTID -s BACKUP_STORAGE -i TEST_IP/CIDR [options]
#   -c  source container ID to test
#   -s  storage that holds the vzdump archives (e.g. a CIFS/NFS backup share)
#   -i  unused static IP/CIDR for the test copy (no gateway is set, so it has no internet)
#   -t  storage for the temporary rootfs (default local-lvm)
#   -b  bridge for the test copy (default vmbr0; use an isolated bridge if you have one)
#   -n  temporary ID (default 9000 + CTID; must be >= 9000 and unused)
#   -a  maximum age of the newest archive in hours (default 30)
#   -k  health check command run inside the copy (default: systemd reaches running/degraded)
# Exit codes: 0 restore + boot + check passed, 1 a test step failed, 2 usage/safety refusal.
set -uo pipefail

ctid=""; store=""; test_ip=""; target=local-lvm; bridge=vmbr0; tid=""; max_age_h=30; check=""; archive=""
while getopts "c:s:i:t:b:n:a:k:h" opt; do
  case "$opt" in
    c) ctid=$OPTARG ;; s) store=$OPTARG ;; i) test_ip=$OPTARG ;; t) target=$OPTARG ;;
    b) bridge=$OPTARG ;; n) tid=$OPTARG ;; a) max_age_h=$OPTARG ;; k) check=$OPTARG ;;
    h) sed -n '2,19p' "$0"; exit 0 ;; *) exit 2 ;;
  esac
done
[[ -n $ctid && -n $store && -n $test_ip ]] || { sed -n '8p' "$0" >&2; exit 2; }
[[ -z $tid ]] && tid=$((9000 + ctid))
node=$(hostname)
log() { printf '%s  %s\n' "$(date '+%F %T')" "$*"; logger -t pve-restore-test -- "$*" 2>/dev/null || true; }
fail() { log "FAIL: $*"; result=FAIL; }

# --- safety guards -------------------------------------------------------------
(( tid >= 9000 )) || { log "refusing: test ID $tid is below 9000"; exit 2; }
if pct status "$tid" >/dev/null 2>&1 || qm status "$tid" >/dev/null 2>&1; then
  log "refusing: ID $tid already exists"; exit 2
fi
ip_only=${test_ip%%/*}
if ping -c1 -W1 "$ip_only" >/dev/null 2>&1; then
  log "refusing: test IP $ip_only already answers on the network"; exit 2
fi

created=0; result=PASS
cleanup() {
  if (( created )); then
    # Only ever destroy the temporary copy this run created.
    if [[ $(pct config "$tid" 2>/dev/null | awk '/^hostname:/ {print $2}') == "restoretest-$ctid" ]]; then
      pct stop "$tid" >/dev/null 2>&1
      pct destroy "$tid" --purge 1 >/dev/null 2>&1 && log "destroyed temporary copy $tid" \
        || log "WARNING: could not destroy $tid, remove it by hand"
    else
      log "WARNING: $tid hostname is not restoretest-$ctid; left in place for a human to check"
    fi
  fi
  log "RESULT: $result (container $ctid, archive ${archive##*/})"
}
trap cleanup EXIT

# --- 1. newest archive and its age ---------------------------------------------
archive=$(pvesh get "/nodes/$node/storage/$store/content" --content backup --vmid "$ctid" --output-format json \
          | jq -r 'sort_by(.ctime) | last | .volid // empty')
[[ -n $archive ]] || { fail "no backup of $ctid found on $store"; exit 1; }
ctime=$(pvesh get "/nodes/$node/storage/$store/content" --content backup --vmid "$ctid" --output-format json \
        | jq -r 'sort_by(.ctime) | last | .ctime')
age_h=$(( ($(date +%s) - ctime) / 3600 ))
log "newest archive: $archive (${age_h}h old)"
(( age_h <= max_age_h )) || fail "newest backup is ${age_h}h old (limit ${max_age_h}h)"

# --- 2. restore -------------------------------------------------------------------
start_ts=$(date +%s)
if ! pct restore "$tid" "$archive" --storage "$target" --unique 1 >/tmp/restoretest-$tid.log 2>&1; then
  fail "pct restore failed (see /tmp/restoretest-$tid.log)"; exit 1
fi
created=1
log "restored to $tid in $(( $(date +%s) - start_ts ))s"

# --- 3. isolate BEFORE first boot: drop every NIC and bind mount, never autostart ---
dels=$(pct config "$tid" | awk -F: '/^(net[0-9]+|mp[0-9]+|lxc\.mount\.entry)/ {print $1}' | sort -u | paste -sd, -)
[[ -n $dels ]] && pct set "$tid" --delete "$dels"
pct set "$tid" --hostname "restoretest-$ctid" --onboot 0 \
  --net0 "name=eth0,bridge=$bridge,ip=$test_ip,firewall=1"
if pct config "$tid" | grep -qE '^(net[1-9]|mp[0-9]|lxc\.mount\.entry)|tag=|gw='; then
  fail "isolation check failed, not starting the copy"; exit 1
fi
log "isolated: removed [${dels:-none}], one untagged NIC at $test_ip, no gateway"

# --- 4. boot and health check -------------------------------------------------------
pct start "$tid" || { fail "container did not start"; exit 1; }
state=$(timeout 120 pct exec "$tid" -- systemctl is-system-running --wait 2>/dev/null || true)
case "$state" in
  running|degraded) log "booted: systemd state '$state'" ;;
  *) fail "systemd did not come up (state '${state:-none}')" ;;
esac
if [[ -n $check ]]; then
  if timeout 60 pct exec "$tid" -- sh -c "$check" >/dev/null 2>&1; then log "health check passed: $check"
  else fail "health check failed: $check"; fi
fi

[[ $result == PASS ]] && exit 0 || exit 1
