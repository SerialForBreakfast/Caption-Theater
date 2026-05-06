#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="Backups/current-experience-${timestamp}"

paths=(
  "README.md"
  "Caption-Theater-POC-Roadmap.md"
  "ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md"
  "CaptionTheater/CaptionTheater/ContentView.swift"
  "CaptionTheater/CaptionTheater/CaptionTheaterApp.swift"
  "CaptionTheater/CaptionTheater/Media"
  "CaptionTheater/CaptionTheater/Playback"
  "CaptionTheater/CaptionTheater/Layout"
  "CaptionTheater/CaptionTheater/Metadata"
  "CaptionTheater/CaptionTheater/Decision"
  "CaptionTheater/CaptionTheater/Debug"
  "CaptionTheater/CaptionTheaterTests/Fixtures"
  "CaptionTheater/CaptionTheaterTests/CaptionTheaterCaptionTextPreferencesTests.swift"
  "CaptionTheater/CaptionTheaterTests/CaptionTheaterLegibleCaptionFormattingTests.swift"
  "CaptionTheater/CaptionTheaterTests/CaptionTheaterScrollingCaptionPolicyTests.swift"
  "CaptionTheater/CaptionTheaterTests/CaptionTheaterLayoutEngineTests.swift"
  "CaptionTheater/CaptionTheaterTests/CaptionTheaterPlaybackShellSnapshotTests.swift"
  "CaptionTheater/CaptionTheaterTests/CaptionTheaterPlaybackEvidenceAssemblerTests.swift"
  "CaptionTheater/CaptionTheaterTests/CaptionTheaterDecisionFixtureTests.swift"
  "CaptionTheater/CaptionTheaterTests/SubtitleMetadataClassifierTests.swift"
  "CaptionTheater/CaptionTheaterTests/HLSManifestInspectorTests.swift"
  "CaptionTheater/CaptionTheaterTests/ProviderMetadataInspectorTests.swift"
)

mkdir -p "$backup_root"

for path in "${paths[@]}"; do
  if [[ -e "$path" ]]; then
    mkdir -p "$backup_root/$(dirname "$path")"
    cp -R "$path" "$backup_root/$path"
  else
    printf 'MISSING %s\n' "$path" >> "$backup_root/MISSING.txt"
  fi
done

{
  printf 'Caption Theater current experience backup\n'
  printf 'Created UTC: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Repository root: %s\n\n' "$(pwd)"

  printf 'Scope:\n'
  printf '%s\n' '- Playback shell and legible-caption rendering source.'
  printf '%s\n' '- Caption text preferences and scrolling caption policy.'
  printf '%s\n' '- Layout, metadata, decision, and debug source supporting current eligibility behavior.'
  printf '%s\n\n' '- Bundled media, playback scenarios, subtitle fixtures, manifest fixtures, provider metadata fixtures, and focused tests.'

  printf 'Git status at backup time:\n'
  git status --short || true
  printf '\n'

  printf 'Source paths:\n'
  printf '%s\n' "${paths[@]}"
  printf '\n'

  printf 'Backup file hashes:\n'
  find "$backup_root" -type f ! -name BACKUP_MANIFEST.txt -print | sort | while read -r file; do
    shasum -a 256 "$file"
  done
} > "$backup_root/BACKUP_MANIFEST.txt"

printf '%s\n' "$backup_root"
