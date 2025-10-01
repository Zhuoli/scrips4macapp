#!/usr/bin/env bash
set -euo pipefail

name="${1:-}"
if [[ -z "$name" ]]; then
  echo "Usage: whatsyourname.sh <name>" >&2
  exit 1
fi

printf "Nice to meet you, %s!\n" "$name"
