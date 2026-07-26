#!/usr/bin/env bash
set -euo pipefail

reference_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for repository in "$reference_root"/upstream/*; do
  if [[ -d "$repository/.git" ]]; then
    git -C "$repository" pull --ff-only
  fi
done

curl -fL --retry 3 \
  https://docs.jaseci.org/llms.txt \
  -o "$reference_root/reference/llms.txt"

curl -fL --retry 3 \
  https://github.com/jaseci-labs/jaseci-llmdocs/releases/latest/download/jac-llmdocs.md \
  -o "$reference_root/reference/jac-llmdocs.md"

curl -fsSL --retry 3 \
  https://zenodo.org/api/records/21498692 \
  -o "$reference_root/reference/zenodo-record.json"

book_url="$(
  jq -r '.files[] | select(.key == "main.pdf") | .links.self' \
    "$reference_root/reference/zenodo-record.json"
)"

curl -fL --retry 3 \
  "$book_url" \
  -o "$reference_root/reference/jac-language-design-book.pdf"

mkdir -p "$reference_root/reference/papers"
for paper_id in 2503.15812 2405.08965 2305.09864 2206.08434; do
  curl -fL --retry 3 \
    "https://arxiv.org/pdf/$paper_id" \
    -o "$reference_root/reference/papers/$paper_id.pdf"
done

echo "Jac references refreshed."
