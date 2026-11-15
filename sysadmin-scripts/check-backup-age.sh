#!/usr/bin/env bash
# check-backup-age.sh - alert when any guest's newest vzdump backup is too old or suspiciously small.
#
# Written after nightly backups stopped silently: the jobs never started, so they never
# failed, and nothing alerted. This checks the result (fresh archives exist), not the job.
#
# Usage: check-backup-age.sh [-d DIR] [-a MAX_AGE_HOURS] [-m MIN_SIZE_MB] [-i "ID ID ..."]
#   -d  backup directory (default /mnt/pve/backups/dump)
#   -a  maximum age of the newest archive per guest, in hours (default 26)
#   -m  minimum archive size in MB (default 1)
#   -i  guest IDs that must have a backup (default: every ID found in the directory)
# Exit codes: 0 all fresh, 1 at least one stale/missing/small, 2 usage or directory error.
set -euo pipefail

dir=/mnt/pve/backups/dump
max_age_h=26
min_mb=1
expect=""

while getopts "d:a:m:i:h" opt; do
  case "$opt" in
    d) dir=$OPTARG ;;
    a) max_age_h=$OPTARG ;;
    m) min_mb=$OPTARG ;;
    i) expect=$OPTARG ;;
    h) sed -n '2,13p' "$0"; exit 0 ;;
    *) exit 2 ;;
  esac
done

[[ -d $dir ]] || { echo "ERROR: backup directory $dir not found (is the share mounted?)" >&2; exit 2; }
# A stale CIFS mount often still "exists" but cannot be listed.
if ! ls "$dir" >/dev/null 2>&1; then
  echo "ERROR: cannot list $dir (stale mount?)" >&2; exit 2
fi

now=$(date +%s)
declare -A newest_ts newest_file
# vzdump names: vzdump-{lxc,qemu}-<id>-YYYY_MM_DD-HH_MM_SS.<ext>
while IFS= read -r -d '' f; do
  base=${f##*/}
  [[ $base =~ ^vzdump-(lxc|qemu)-([0-9]+)-([0-9]{4})_([0-9]{2})_([0-9]{2})-([0-9]{2})_([0-9]{2})_([0-9]{2})\. ]] || continue
  [[ $base == *.log || $base == *.notes ]] && continue
  id=${BASH_REMATCH[2]}
  ts=$(date -d "${BASH_REMATCH[3]}-${BASH_REMATCH[4]}-${BASH_REMATCH[5]} ${BASH_REMATCH[6]}:${BASH_REMATCH[7]}:${BASH_REMATCH[8]}" +%s)
  if [[ -z ${newest_ts[$id]:-} || $ts -gt ${newest_ts[$id]} ]]; then
    newest_ts[$id]=$ts; newest_file[$id]=$f
  fi
done < <(find "$dir" -maxdepth 1 -type f -name 'vzdump-*' -print0)

ids=$expect
[[ -z $ids ]] && ids=$(printf '%s\n' "${!newest_ts[@]}" | sort -n | tr '\n' ' ')
[[ -z ${ids// /} ]] && { echo "FAIL: no vzdump archives found in $dir"; exit 1; }

bad=0
printf '%-8s %-8s %-10s %s\n' "GUEST" "STATUS" "AGE(h)" "NEWEST ARCHIVE"
for id in $ids; do
  if [[ -z ${newest_ts[$id]:-} ]]; then
    printf '%-8s %-8s %-10s %s\n' "$id" "MISSING" "-" "-"; bad=1; continue
  fi
  age_h=$(( (now - newest_ts[$id]) / 3600 ))
  size_mb=$(( $(stat -c %s "${newest_file[$id]}") / 1024 / 1024 ))
  status=OK
  (( age_h > max_age_h )) && status=STALE
  (( size_mb < min_mb )) && status=SMALL
  [[ $status != OK ]] && bad=1
  printf '%-8s %-8s %-10s %s (%s MB)\n' "$id" "$status" "$age_h" "${newest_file[$id]##*/}" "$size_mb"
done

exit $bad
