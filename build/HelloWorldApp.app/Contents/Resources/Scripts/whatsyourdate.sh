#!/usr/bin/env bash
set -euo pipefail

input="${1:-}"
if [[ -z "$input" ]]; then
  echo "Usage: whatsyourdate.sh <YYYY-MM-DD>" >&2
  exit 1
fi

if formatted=$(date -j -f "%Y-%m-%d" "$input" "+%A, %B %d %Y" 2>/dev/null); then
  echo "You picked $formatted."
else
  echo "Unable to parse '$input'. Expected format: YYYY-MM-DD" >&2
  exit 64
fi
