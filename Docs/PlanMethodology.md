# Planning Methodology: Practical Proof Before Ambitious UI

Date: 2026-05-09  
Status: Project planning guidance

Caption Theater's current MVP is a meaningful proof of concept because it solves a real user problem in a way that is visible, explainable, and testable: ultra-wide video can preserve its geometry while the lower reading region shows multiple lines of already-presented caption text, giving viewers more time to read without covering the picture.

That is the reference point for future planning. Success is not measured by how ambitious an idea sounds. Success is measured by whether the prototype makes a user task better under real constraints.

## What we learned

### Good ideas from the multi-speaker exploration

- **Caption Theater's core value is strong:** more readable dwell time, larger text space, and unobstructed video are enough to explain the product.
- **The larger caption region matters:** showing multiple lines in the new view size makes the value obvious because users can finish reading without losing the active picture.
- **Speaker identity is useful when authored:** SDH labels, `Speaker:` conventions, and WebVTT voice spans can improve comprehension when they actually exist.
- **Fallback discipline matters:** neutral captions without speaker chrome are better than pretending we know who spoke.
- **Backups matter:** offline media, local playlists, subtitle files, provenance, and checksum manifests make demos durable.
- **Asset gates matter:** a feature that depends on rare data should not reach implementation until the data exists in a usable asset.

### Bad ideas or weak planning patterns

- **Chasing cool UI before proving inputs exist:** SMS balloons and chat layouts are interesting, but they require reliable speaker identity. Without a qualifying asset, they are theory.
- **Treating sidecars as product evidence:** a local `speaker-map.json` can test renderer mechanics, but it does not prove real streams carry speaker attribution.
- **Confusing technical possibility with practical availability:** WebVTT can encode voice spans; that does not mean usable public HLS assets commonly include them.
- **Letting a demo fixture become a product claim:** internal PoC annotations must not imply catalog-wide support.
- **Overvaluing technical correctness over user value:** a clever parser or UI is not valuable if it does not improve the viewer's real caption experience.

This was not a failure. It clarified the boundary between the product's proven value and a speculative enhancement.

## Planning standard

Every future feature plan should pass these questions before implementation:

1. **What user problem does this solve?**  
   State the viewer pain in plain language. If the answer is mainly "it would be cool," keep it in brainstorming.

2. **What ground truth makes this possible?**  
   Identify the real asset, API, metadata, user setting, platform behavior, or fixture that proves the feature can work.

3. **Can we demo it offline or with a durable backup?**  
   If a demo depends on a fragile URL, private stream, unclear license, or missing media backup, it is not ready.

4. **What is the smallest verifiable milestone?**  
   Prefer a narrow working prototype over an impressive plan. For Caption Theater, the current benchmark is: video geometry preserved, multiple caption lines visible, no future cues, and user value obvious.

5. **What happens when the ideal signal is missing?**  
   The fallback should still be useful. If the feature collapses without rare metadata, it is not core MVP work.

6. **What would make us kill the idea?**  
   Define the failure condition before starting. If no qualifying asset exists, stop planning UI that depends on it.

## Language for future agents

Use this language when asking agents to plan or evaluate work:

> Optimize for demonstrated user value, not novelty. A plan is not practical until it names the real assets, APIs, data, fixtures, backups, and acceptance checks that make the feature possible.

> Before proposing UI, prove the required inputs exist. If the feature depends on metadata, identify the exact file, format, stream, API, or fixture that supplies it. If no such input exists, mark the idea speculative and do not implement it.

> Separate technical possibility from practical availability. "The format supports it" is not evidence that real assets provide it.

> Treat local annotations and synthetic fixtures as test tools, not product evidence. They can prove renderer mechanics, but they cannot prove market or catalog viability.

> Define a kill condition. If the asset gate fails, park the feature and redirect effort to the highest-confidence user problem.

> Preserve the current MVP's clarity: Caption Theater gives captions more readable time and space while preserving the picture. Any extension must strengthen that story or stay out of the core path.

## Agent prompting guidelines

Good agent prompts should force the work toward evidence, implementation boundaries, and user value. Weak prompts often leave room for the agent to satisfy the surface request with plausible-sounding abstractions.

### Prompt for ground truth first

Use when the work depends on assets, APIs, metadata, platform behavior, or external availability.

Good:

> Before proposing implementation, inspect the repo and identify the exact files, assets, APIs, or fixtures that make this possible. If the required input does not exist, say so and stop before planning UI.

Bad:

> Come up with a cool way to show multi-speaker captions.

Why the good prompt works:

- It requires discovery before design.
- It gives the agent permission to reject the premise.
- It prevents format support from being mistaken for real asset availability.

Why the bad prompt fails:

- It rewards creative UI output even if the required subtitle data does not exist.
- It does not define what would make the idea practical.

### Prompt for user value, not feature shape

Good:

> The goal is to help viewers read captions more comfortably. Propose only changes that improve reading time, reduce obstruction, or preserve context. Rank ideas by how directly they solve that user problem.

Bad:

> Add advanced caption features.

Why the good prompt works:

- It anchors the agent in the viewer problem.
- It makes the current MVP legible as success.
- It filters novelty that does not improve caption reading.

Why the bad prompt fails:

- "Advanced" is ambiguous.
- It can lead to speculative features such as chat UI, diarization, or spatial speaker anchoring without proving they help this prototype.

### Prompt for gates and kill conditions

Good:

> Create an asset-gated plan. Define the exact requirements an asset must meet. If no asset qualifies, the output should explicitly park the feature and redirect to the strongest practical alternative.

Bad:

> Make a plan for the ideal demo.

Why the good prompt works:

- It tells the agent that "no" is an acceptable outcome.
- It produces tasks that can be executed or rejected.
- It prevents implementation from starting on impossible prerequisites.

Why the bad prompt fails:

- "Ideal" invites wishful thinking.
- The plan may become a list of dependencies we do not have.

### Prompt for backup and reproducibility

Good:

> For every demo dependency, state whether it works offline, where it is stored, how it is backed up, what license/provenance applies, and what test proves the backup is complete.

Bad:

> Use a public stream for the demo.

Why the good prompt works:

- It turns a demo into a durable engineering artifact.
- It exposes fragile URLs, unclear redistribution, and missing subtitle files.

Why the bad prompt fails:

- Public does not mean stable, licensed, or backuppable.
- A demo can silently depend on network state or CDN behavior.

### Prompt for implementation-safe scope

Good:

> Do not edit playback code yet. Produce a doc-only feasibility review with specific go/no-go criteria, then list the smallest implementation slice if the gate passes.

Bad:

> Let's add this feature.

Why the good prompt works:

- It prevents premature code changes.
- It separates research, planning, and implementation.

Why the bad prompt fails:

- The agent may infer permission to build before the idea is ready.
- Speculative work can contaminate the MVP path.

## Prompt ambiguity traps

These phrases need clarification or grounding because agents can interpret them too broadly:

| Ambiguous phrase | Risk | Better prompt language |
|------------------|------|------------------------|
| "Could we..." | Agent answers theoretical possibility. | "Is this practical with assets/APIs available in this repo or publicly backuppable sources?" |
| "It would be cool if..." | Agent optimizes for novelty. | "Only pursue this if it directly improves the current user problem and has verifiable inputs." |
| "Make a demo" | Agent may use fragile/manual assumptions. | "Make a demo that works offline or has a documented backup chain." |
| "Use subtitles" | Subtitle type is unclear. | "Use raw text subtitles with cue timing available to our renderer; reject burned-in/image-only subtitles." |
| "Speaker-aware" | Could mean labels, diarization, colors, lanes, or chat UI. | "Use only source-authored speaker labels; no inference; neutral fallback when unknown." |
| "Production-ready" | Can mean tests, polish, architecture, or release rights. | "Define tests, source rights, offline assets, failure behavior, and exact launch path." |
| "Best possible" | Encourages unbounded ambition. | "Best practical result under current repo assets, platform limits, and backup requirements." |

## What succeeded in this project

### Successful prompt pattern: make the current experience concrete

The strongest outcomes came from prompts that asked for a tangible, verifiable user experience:

> Add a visible border around the player so layout changes are obvious.

This worked because the request was concrete, local, and measurable. It made the layout behavior easier to see without changing the product thesis.

### Successful prompt pattern: protect the demo from network failure

The offline HLS work succeeded because the request focused on a practical demo risk:

> Bring in the stream for an offline backup and make it selectable with launch arguments.

This worked because the success criteria were observable: app launches with local HLS, media and subtitles are bundled, and the demo can work without internet.

### Successful prompt pattern: keep configuration out of the UI

The feature-toggle discussion improved once the scope became explicit:

> I do not want feature toggles in the UI for now. Keep them in code as configuration for testing.

This worked because it separated developer control from product UI and prevented a debugging surface from becoming part of the experience.

### Successful prompt pattern: force feasibility review

The multi-speaker work improved when the prompt challenged the premise:

> The possible is not the practical. If we cannot find assets that fulfill this online, is that evidence it is not viable?

This worked because it shifted the task from UI invention to evidence gathering.

## What went off track

### Off-track pattern: accepting an invented fixture as proof

The sidecar `speaker-map.json` idea was technically useful but product-weak. It could prove that a renderer works, but not that real streaming assets support the feature.

Better framing:

> A sidecar may be used only as an internal renderer test. It cannot be used as evidence that the product should advertise speaker-aware chat UI.

### Off-track pattern: UI before asset qualification

The SMS/balloon concept became tempting before a qualifying asset existed.

Better framing:

> Do not design SMS, bubble, lane, or spatial speaker UI until an asset passes the source-authored speaker identity gate.

### Off-track pattern: relying on format capability

WebVTT voice spans are real, but that does not prove the available assets use them.

Better framing:

> Format support is only Tier 1 evidence. The implementation gate requires inspected assets or platform output that exposes the signal.

### Off-track pattern: broad task lists without stopping rules

Long task lists can look actionable while hiding a missing prerequisite.

Better framing:

> Put gate tasks first. If the gate fails, all downstream renderer tasks are parked automatically.

## Great vs bad prompt examples

### Example 1: asset-dependent feature

Great:

> Investigate whether SMS-style multi-speaker captions are practical. First find at least one backuppable asset with source-authored speaker identity and cue-level timing. If none exists, document that the idea is parked and recommend the highest-value alternative.

Bad:

> Build a cool SMS-style caption interface for dialogue.

### Example 2: caption readability

Great:

> Improve caption readability in the current MVP. Preserve video geometry, never reveal future cues, use the lower reading region for multiple already-presented lines, and verify the result against the offline HLS mock.

Bad:

> Make subtitles better.

### Example 3: research task

Great:

> Produce a feasibility audit. Cite real sources, inspect local assets, distinguish format support from asset prevalence, and assign go/no-go recommendations.

Bad:

> Research whether this is possible.

### Example 4: implementation task

Great:

> Implement only the code-level launch/configuration path for selecting the bundled offline HLS mock. Do not add user-facing feature toggles. Add tests that prove the selected source resolves to local bundled media.

Bad:

> Add feature toggles so we can switch things around.

### Example 5: docs task

Great:

> Write a proposal that lists what succeeds, what fails, exact asset requirements, backup requirements, acceptance criteria, and kill conditions. Mark speculative ideas as parked.

Bad:

> Write up the idea.

## Agent output checklist

Before accepting an agent's plan or patch, check whether it answers:

- What user problem is being solved?
- What exact repo file, asset, stream, API, or platform behavior makes it possible?
- What proves it works without relying on private or fragile dependencies?
- What is the fallback when the ideal input is missing?
- What tests or manual checks prove the behavior?
- What is explicitly out of scope?
- What condition kills or parks the idea?

If these answers are missing, ask for a revision before implementation.

## Success vs failure reference

### Verifiable success

A milestone is successful when it can be shown and explained simply:

- The video remains undistorted.
- The caption region uses otherwise unused space.
- Multiple lines are visible long enough to help real reading.
- No future dialogue is revealed.
- The user can understand why this is better than native subtitles.
- The demo works from known local assets or documented, reliable sources.

This is why the current MVP is sufficient for this phase. It demonstrates a concrete user solution, not merely a technical trick.

### Warning signs

A plan is drifting when:

- the required asset does not exist yet;
- the required metadata is rare, unverified, or invented;
- the UI is more developed than the data model or source evidence;
- the fallback is "do nothing useful";
- the feature is hard to explain without speculative future capabilities;
- the plan would be embarrassing if shown with the actual available media.

## Practical planning template

Use this structure for future feature docs:

```text
Feature:
User problem:
Current MVP relationship:
Required ground truth:
Known assets / APIs:
Backup plan:
Smallest verifiable milestone:
Acceptance criteria:
Fallback behavior:
Kill condition:
Out of scope:
```

Do not move from plan to implementation until the "Required ground truth," "Known assets / APIs," "Backup plan," and "Kill condition" sections are concrete.

## Applying this to multi-speaker captions

The useful product direction is:

- preserve authored speaker labels when they exist;
- parse visible SDH labels or WebVTT voice spans opportunistically;
- keep unknown captions neutral;
- prioritize wrapping, text size, retention, and readability.

The parked direction is:

- SMS balloons;
- chat-style left/right alignment;
- speaker lanes;
- color-primary speaker identity;
- any claim that Caption Theater can identify speakers when the captions do not.

Those ideas can return only if we find or create a real qualifying asset with source-authored speaker identity, backup rights, cue-level timing, and a scene that proves the UI.

## Principle

Technical correctness is necessary, but it is not the goal. The goal is solving a viewer problem.

Caption Theater succeeds when the user can say: "I had more time and space to read the captions without losing the movie."
