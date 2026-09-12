#!/usr/bin/env bash
# Stop hook on the orchestrator session. Copies pipeline paperwork to a bucket if PIPELINE_BUCKET is set.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -z "${PIPELINE_BUCKET:-}" ] && exit 0
dest="$PIPELINE_BUCKET/$(basename "$root")/$(date +%F)"
if   command -v aws    >/dev/null; then aws s3 sync "$root/pipeline/" "s3://$dest/pipeline/" --exclude queue.md >/dev/null 2>&1; aws s3 sync "$root/wiki/" "s3://$dest/wiki/" >/dev/null 2>&1
elif command -v gsutil >/dev/null; then gsutil -m rsync -r "$root/pipeline/" "gs://$dest/" >/dev/null 2>&1
elif command -v rclone >/dev/null; then rclone sync "$root/pipeline/" "$dest/" --exclude queue.md >/dev/null 2>&1
fi
exit 0   # never block the session on a sync failure
