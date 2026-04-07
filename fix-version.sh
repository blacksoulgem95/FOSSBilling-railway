#!/usr/bin/env bash
# Resolve Docker Hub (or default registry) manifests and rewrite FROM lines to
# image:tag@sha256:<digest> so tags stay explicit for the next weekly bump.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${1:-$ROOT/Dockerfile}"

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "error: Dockerfile not found: $DOCKERFILE" >&2
  exit 1
fi

resolve_digest() {
  local ref=$1
  local d=""
  if d=$(docker buildx imagetools inspect "$ref" --format '{{.Digest}}' 2>/dev/null); then
    if [[ "$d" =~ ^sha256:[a-f0-9]{64}$ ]]; then
      echo "$d"
      return 0
    fi
  fi
  docker pull -q "$ref" >/dev/null
  d=$(docker inspect --format='{{index .RepoDigests 0}}' "$ref" 2>/dev/null | sed -n 's/.*@\(sha256:[a-f0-9]\{64\}\)$/\1/p')
  if [[ "$d" =~ ^sha256:[a-f0-9]{64}$ ]]; then
    echo "$d"
    return 0
  fi
  echo "error: could not resolve digest for: $ref" >&2
  return 1
}

pull_ref_from_spec() {
  local spec=$1
  local base
  if [[ "$spec" == *@sha256:* ]]; then
    base="${spec%@sha256:*}"
  else
    base="$spec"
  fi
  if [[ "$base" != *:* ]]; then
    base="${base}:latest"
  fi
  echo "$base"
}

rewrite_from_line() {
  local line=$1
  local prefix=""
  if [[ "$line" =~ ^([[:space:]]*) ]]; then
    prefix="${BASH_REMATCH[1]}"
  fi
  local trimmed comment=""
  if [[ "$line" == *"#"* ]]; then
    trimmed="${line%%#*}"
    comment="#${line#*#}"
  else
    trimmed="$line"
  fi
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
  trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"

  if [[ ! "$trimmed" =~ ^[Ff][Rr][Oo][Mm][[:space:]]+([^[:space:]]+)([[:space:]]+[Aa][Ss][[:space:]]+([^[:space:]]+))? ]]; then
    echo "$line"
    return 0
  fi

  local spec="${BASH_REMATCH[1]}"
  local as_suffix=""
  if [[ -n "${BASH_REMATCH[3]:-}" ]]; then
    as_suffix=" AS ${BASH_REMATCH[3]}"
  fi

  local pull_ref
  pull_ref="$(pull_ref_from_spec "$spec")"
  local digest
  digest="$(resolve_digest "$pull_ref")"
  local new_spec="${pull_ref}@${digest}"

  local rebuilt="${prefix}FROM ${new_spec}${as_suffix}"
  if [[ -n "$comment" ]]; then
    rebuilt="${rebuilt} ${comment}"
  fi
  echo "$rebuilt"
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^[[:space:]]*([Ff][Rr][Oo][Mm][[:space:]]) ]]; then
    rewrite_from_line "$line" >>"$tmp"
  else
    printf '%s\n' "$line" >>"$tmp"
  fi
done <"$DOCKERFILE"

mv "$tmp" "$DOCKERFILE"
trap - EXIT

echo "Updated $DOCKERFILE"
