#! /bin/bash -e
# Check the local base images against base-image.lock. Exits non-zero on mismatch.
#   docker/verify_base.sh            verify
#   docker/verify_base.sh --restore  load an archive first if an image is absent

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/base-image.lock"
ARCHIVE_DIR="${NERVE_BASE_ARCHIVE_DIR:-$HOME/.cache/nerve-base}"
field() { awk -v k="$1" '$1==k {print $2}' "$LOCK"; }

restore=0
[ "${1:-}" = "--restore" ] && restore=1
fail=0

check() {   # <image> <digest> <config> <archive filename> <archive_sha256> [optional]
    local image=$1 digest=$2 config=$3 archive="$ARCHIVE_DIR/$4" asha=$5 opt=${6:-0} bad=0 got_config got_digest

    if [ "$restore" = 1 ] && [ "$opt" != 1 ] && ! docker image inspect "$image" >/dev/null 2>&1; then
        if [ -f "$archive" ]; then
            echo "$asha  $archive" | sha256sum -c -
            docker load -i "$archive"
        else
            # No local copy: the digest is content-addressed, so a pull is equivalent.
            docker pull "${image%:*}@$digest"
        fi
        # Both routes restore untagged; re-tagging an already tagged image is a no-op.
        docker tag "$config" "$image"
    fi

    if ! docker image inspect "$image" >/dev/null 2>&1; then
        [ "$opt" = 1 ] && { echo "skipped: $image not present"; return 0; }
        echo "absent: $image (try --restore, or pull ${image%:*}@$digest)" >&2
        fail=1
        return 0
    fi

    got_config="$(docker image inspect "$image" --format '{{.Id}}')"
    got_digest="$(docker image inspect "$image" --format '{{range .RepoDigests}}{{println .}}{{end}}' \
        | grep -o 'sha256:[0-9a-f]*' | head -1)"

    [ "$got_config" = "$config" ] || { echo "config mismatch: $image $got_config != $config" >&2; bad=1; }
    if [ -n "$got_digest" ] && [ "$got_digest" != "$digest" ]; then
        echo "registry digest mismatch: $image $got_digest != $digest" >&2; bad=1
    fi
    # Always return 0, so one bad image does not hide the other under set -e.
    if [ "$bad" = 0 ]; then echo "OK: $image $config"; else fail=1; fi
    return 0
}

check "$(field base_image)"         "$(field base_digest)" "$(field base_config)" \
      "$(field base_archive_file)"  "$(field base_archive_sha256)"
check "$(field psortb_image)"        "$(field psortb_digest)" "$(field psortb_config)" \
      "$(field psortb_archive_file)" "$(field psortb_archive_sha256)"
check "$(field prev_image)"        "$(field prev_digest)" "$(field prev_config)" \
      "$(field prev_archive_file)" "$(field prev_archive_sha256)" 1
check "$(field published_image)"        "$(field published_digest)" "$(field published_config)" \
      "$(field published_archive_file)" "$(field published_archive_sha256)" 1

exit "$fail"
