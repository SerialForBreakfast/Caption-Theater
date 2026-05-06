# Current Experience Backups

Use `Scripts/create_current_experience_backup.sh` before changing playback, caption rendering, layout geometry, subtitle metadata parsing, or eligibility decisions.

The script creates a repo-local snapshot in `Backups/current-experience-YYYYMMDD-HHMMSS/`. It copies the source, fixtures, media, and focused tests that define the current Caption Theater playback and subtitling experience.

The backup intentionally stays inside this repository. Do not move private media, protected frames, credentials, cookies, certificates, FairPlay keys, private stream URLs, or unsanitized production manifests into these snapshots.

Run:

```sh
Scripts/create_current_experience_backup.sh
```

Each backup includes `BACKUP_MANIFEST.txt` with:

- creation time;
- source paths included;
- read-only `git status --short` output;
- SHA-256 hashes for copied files.

To compare a backed-up file with the current working copy, use `diff` or your editor against the matching path under `Backups/current-experience-*`.
