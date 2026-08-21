#!/usr/bin/env bash

set -euo pipefail

revision="724fb5abbf5502583fb520898d45929e62f02c0b"
short_revision="724fb5a"
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_source="$repository_root/manifests/supertonic-3-${short_revision}.json"
output_dir="${1:-$repository_root/dist}"
work_dir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/bookmanager-supertonic-3-${short_revision}.XXXXXX")"
package_dir="$work_dir/supertonic-3"
archive_name="bookmanager-supertonic-3-${short_revision}.zip"
manifest_name="bookmanager-supertonic-3-${short_revision}.manifest.json"
checksum_name="${archive_name}.sha256"

mkdir -p "$package_dir" "$output_dir"

while IFS=$'\t' read -r bundle_path expected_size expected_sha256; do
    source_path="$bundle_path"
    if [[ "$bundle_path" == "LICENSE.supertonic-openrail.txt" ]]; then
        source_path="LICENSE"
    fi

    destination="$package_dir/$bundle_path"
    mkdir -p "$(dirname "$destination")"
    curl \
        --fail \
        --location \
        --retry 3 \
        --retry-all-errors \
        --silent \
        --show-error \
        --output "$destination" \
        "https://huggingface.co/Supertone/supertonic-3/resolve/${revision}/${source_path}?download=true"

    actual_size="$(wc -c < "$destination" | tr -d '[:space:]')"
    actual_sha256="$(sha256sum "$destination" | awk '{print $1}')"
    if [[ "$actual_size" != "$expected_size" || "$actual_sha256" != "$expected_sha256" ]]; then
        echo "Verification failed: $bundle_path" >&2
        exit 1
    fi
done < <(jq -r '.files[] | [.path, (.size | tostring), .sha256] | @tsv' "$manifest_source")

cp "$manifest_source" "$package_dir/manifest.json"
printf '%s\n' \
    'BookManager Supertonic 3 Model Bundle' \
    '' \
    'This bundle redistributes unmodified model assets from Supertonic 3 by Supertone.' \
    '' \
    'Source: https://huggingface.co/Supertone/supertonic-3' \
    "Pinned revision: $revision" \
    'License: OpenRAIL-M (see LICENSE.supertonic-openrail.txt)' \
    '' \
    'BookManager adds only this notice, the manifest, and archive packaging.' \
    > "$package_dir/NOTICE.txt"

find "$package_dir" -type f -exec touch -t 200001010000 {} +

archive_path="$output_dir/$archive_name"
checksum_path="$output_dir/$checksum_name"
release_manifest_path="$output_dir/$manifest_name"
rm -f "$archive_path" "$checksum_path" "$release_manifest_path"

(
    cd "$work_dir"
    find supertonic-3 -type f -print | LC_ALL=C sort | zip -X -9 "$archive_path" -@
)

unzip -t "$archive_path"
cp "$manifest_source" "$release_manifest_path"
(
    cd "$output_dir"
    sha256sum "$archive_name" > "$checksum_name"
)

ls -lh "$archive_path" "$checksum_path" "$release_manifest_path"
