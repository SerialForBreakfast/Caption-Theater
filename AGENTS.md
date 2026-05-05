# Agent Rules

## Repository Boundary

Work only inside this repository. Put generated code, scripts, fixtures, logs, build artifacts, scratch files, and docs in project-local folders such as `Fixtures/`, `Scripts/`, `Docs/`, `Tests/`, `Logs/`, or `Scratch/`.

Never write to `/tmp`, `/private/tmp`, `/var/tmp`, Desktop, Downloads, home-directory scratch paths, global config/cache folders, sibling repos, unrelated folders, or system folders.

If an external write seems necessary, stop and ask first. State the exact path, why repo-local storage is insufficient, and what data would be written. No explicit approval means no external write.

## Git (agents — read-only)

**Agents must not mutate Git state.** Use Git only for **read-only** inspection (for example: `git status`, `git diff`, `git log`, `git show`, `git ls-files`, `git check-ignore`, viewing refs).

**Never**, unless the human explicitly instructs otherwise:

- stage or unstage (`git add`, `git rm`, restore/stash affecting index)
- commit, merge, rebase, cherry-pick, reset that changes branches or history
- push, fetch/pull when it updates refs as part of agent-initiated automation

If untracking files, fixing `.gitignore`, or any repository bookkeeping requires writes, **output the exact commands** for the human to run locally. Do not execute them.

## Communication

Before broad edits, state the intended files, new folders, and whether the work touches playback, captions, metadata, ads, DRM, accessibility, or platform behavior. After edits, summarize what changed and what should be tested.

## Privacy

Do not commit or log credentials, tokens, cookies, certificates, FairPlay keys, private stream URLs, raw protected frames, private media, or unsanitized production manifests. Use placeholders and sanitized fixtures.

## Product Direction

Caption Theater uses unused cinema-aspect-ratio space for unobstructed, persistent captions.

Preserve these rules:

- persist already-presented cues;
- never reveal future cues by default;
- preserve video geometry;
- prompt before entering the hero flow;
- let ads play normally fullscreen/native;
- suspend and revalidate around ads;
- treat 4:3, variable-aspect, and burned-in subtitle cases as stretch-goal classifications;
- implement WebVTT first while keeping the cue model extensible.

Do not reframe the project as a transcript viewer, future-subtitle previewer, subtitle editor, or full custom player replacement.

## Swift Standards

Use descriptive names, intentional optionality, intentional access control, and `let` by default. Avoid force unwraps unless the invariant is obvious and documented. Add useful Xcode Quick Help comments for important types/APIs. Keep platform-specific code in small adapters. Do not add emojis to code, logs, tests, or engineering docs.

## Concurrency

For async or actor-related changes, document actor ownership, cancellation, main-actor requirements, and how playback, subtitle, ad, and layout state changes are handled. UI updates must run on the main actor. Pixel analysis, manifest parsing, provider metadata parsing, and cue processing must not block the main actor.

## Tests

Add meaningful tests for state transitions, evidence decisions, HLS/provider metadata parsing, viewport detection, layout geometry, caption persistence, and ad/promo boundaries. Do not skip, disable, or weaken tests to pass a run. If tests fail, explain what failed and why.

## New Abstractions

Before creating a protocol, class, enum, file, or fixture format, search for an existing implementation. Avoid duplicates. If a new abstraction is needed, document why it exists, what owns it, and how it should be tested.

## Stop and Ask

Stop before external writes, `/tmp` usage, global installs, system setting changes, edits outside this project, private credentials/media, background services, weakened tests, broad architecture changes, **or any Git command that modifies history, the index, or remote-tracking refs (agents use Git read-only; see Git section above).**
