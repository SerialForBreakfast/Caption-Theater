# Open Source Release Checklist

Caption Theater can use Apache License 2.0 for source code, but the current working tree still contains tracked private/demo artifacts that should be removed or reviewed before the repository is made public.

The generated fixture under `CaptionTheater/CaptionTheater/Media/OfflineHLS/CaptionTheaterGeneratedWidescreenFixture/` is project-owned video-only media with timed captions and can remain as the default public demo asset.

## License Files

- [x] Add `LICENSE` with Apache License 2.0.
- [x] Add `NOTICE`.
- [x] Add `THIRD_PARTY_NOTICES.md`.
- [ ] Confirm copyright owner spelling before release.

## Required Human Git Cleanup

Repository instructions require agents to keep Git read-only. Run these commands locally when you are ready to remove tracked private/local artifacts.

```sh
git rm -r Backups
git rm -r CaptionTheater/CaptionTheater.xcodeproj/xcuserdata
git rm -r CaptionTheater/CaptionTheater.xcodeproj/project.xcworkspace/xcuserdata
git rm -r Scripts/__pycache__
```

Remove bundled media unless redistribution has been cleared:

```sh
git rm -r CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock
git rm CaptionTheater/CaptionTheater/Media/CaptionTheaterSamplePlayback.mp4
```

Do not remove the generated fixture unless you intentionally want a source-only checkout with no bundled offline demo:

```text
CaptionTheater/CaptionTheater/Media/OfflineHLS/CaptionTheaterGeneratedWidescreenFixture/
```

If you choose to keep any media, document its source, license, modifications, and attribution in `THIRD_PARTY_NOTICES.md` before making the repository public.

## Recommended Ignore Rules

Add these to `.gitignore` before public release:

```gitignore
.DS_Store
Build/
DerivedData/
Screenshots/
Logs/
Scratch/
*.xcuserstate
xcuserdata/
__pycache__/
*.pyc
```

## Public Readiness Checks

- [ ] `git status --short` contains no accidental local user state.
- [ ] No private stream URLs, signed URLs, cookies, FairPlay keys, certificates, or protected frames are present.
- [ ] No private media remains in tracked files.
- [ ] README accurately describes the current platform targets.
- [ ] `THIRD_PARTY_NOTICES.md` covers every retained third-party asset.
- [ ] The app builds from a clean checkout without private assets, or missing demo media is clearly documented.
- [ ] The repo visibility is changed only after the cleanup commit is reviewed.
