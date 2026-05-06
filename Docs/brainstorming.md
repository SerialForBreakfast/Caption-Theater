

# Aspect-Ratio Adaptive Content Enhancements

Status: Brainstorming  
Project: Caption Theater  
Focus: Creative uses for unused cinema-aspect-ratio space during widescreen playback

---

## Product Frame

Caption Theater starts with a clear, high-value use case: ultra-widescreen content on a 16:9 screen often leaves unused letterbox space. Instead of letting that area remain empty, we can use it as an adaptive experience layer.

The first and strongest use case is unobstructed caption persistence: captions get more room, can remain visible longer, and do not cover the active picture.

This document explores what else could live in that space when it genuinely improves the viewing experience.

The key question for every idea:

> Does this help the viewer understand, enjoy, access, or control the content without distracting from the content itself?

---

## Design Principles

## Accessibility Needs to Design For

The extra screen area is most valuable when it solves a specific access need. W3C’s media accessibility requirements describe captions, transcripts, audio description, sign language, and synchronization as distinct ways people access time-based media. Apple’s media accessibility guidance also emphasizes respecting systemwide caption and audio-description preferences. Caption Theater should build on those ideas by using safe cinema-layout space to make existing access features more readable, discoverable, and configurable.

Accessibility needs to consider:

- Deaf and hard-of-hearing viewers who rely on captions, SDH cues, speaker labels, and non-speech sound descriptions.
- Low-vision viewers who need larger text, stronger contrast, less overlap, and less visual clutter.
- Blind viewers who rely on audio description, descriptive transcripts, and clear access to media alternatives.
- DeafBlind viewers who may benefit from descriptive transcript surfaces and external assistive technology compatibility.
- Neurodivergent viewers who may benefit from explicit tone, speaker, social-context, or sensory-context support.
- Viewers with cognitive or learning disabilities who benefit from more time, simpler layouts, familiar controls, and reduced memory burden.
- Viewers with attention, fatigue, migraine, vestibular, or sensory sensitivities who may need low-motion, low-flash, low-clutter modes.
- Second-language viewers and language learners who need more time, phrase context, vocabulary, or original/translated text comparison.
- Older viewers and living-room viewers who need larger captions, simpler controls, and better readability from a distance.

The extra area should not become a catch-all dashboard. It should become a user-controlled access layer with modes tailored to specific needs.

---

1. **The movie remains primary.**  
   The extra area should support the content, not compete with it.

2. **No future spoilers by default.**  
   Enhancements should not reveal future dialogue, plot points, outcomes, or jokes.

3. **Opt-in by default.**  
   Most enhancements should be user-selectable modes, not automatic overlays.

4. **Context beats clutter.**  
   One useful piece of information is better than a dashboard of noise.

5. **Distraction cost must be evaluated.**  
   Every feature needs a distraction rating and a clear reason to exist.

6. **Ads remain native/fullscreen.**  
   Enhancements suspend during ads and resume or revalidate when content returns.

7. **Metadata must be trusted.**  
   Character names, trivia, recap content, emotional cues, and translations should come from trusted metadata, verified models, or controlled pipelines.

---

## Feasibility Scale

| Rating | Meaning |
|---|---|
| High | Can be prototyped with local metadata, subtitles, or player state. |
| Medium | Requires timed metadata, model inference, or content pipeline support. |
| Low | Requires complex rights, unreliable inference, heavy ML, or partner metadata. |

## Distraction Scale

| Rating | Meaning |
|---|---|
| Low | Passive, brief, and directly supports the current scene. |
| Medium | Useful but could pull attention away if overused. |
| High | Likely to compete with the movie unless user explicitly requests it. |

---

## Highest-Value Ideas

### 1. Persistent Multi-Line Captions

Use the lower letterbox area for current and recently presented caption cues.

Value:

- More readable dwell time.
- Less rewinding.
- Better support for fast dialogue.
- Better support for translated subtitles that expand in length.
- Better support for SDH speaker labels and sound effects.
- Captions do not obstruct the active picture.

Feasibility: High for WebVTT, medium for CEA-608/708 and IMSC/TTML.  
Distraction risk: Low when bounded to a small cue history.  
MVP fit: Core feature.

Notes:

- This remains the strongest product value.
- Retained cues should be visually de-emphasized.
- No future cues should appear by default.
- Large text and multi-line display are obvious accessibility wins.

---

### 2. Large Caption Mode

Use the extra area to show larger captions without covering the picture.

Value:

- Better readability from living-room distances.
- Helps low-vision users.
- Helps users watching on smaller screens.
- Helps captions remain useful without sacrificing active-picture visibility.

Feasibility: High for custom-rendered text captions.  
Distraction risk: Low to medium depending on size.  
MVP fit: Strong candidate.

Notes:

- Should respect system caption preferences where possible.
- Large text may reduce retained cue count.
- This could be a simple first setting: Normal, Large, Extra Large.

---

### 3. X-Ray Style Scene Context

Show scene-relevant information such as actor names, character names, music, locations, or trivia.

Value:

- Helps viewers identify “who is that?” without pausing or pulling out a phone.
- Supports rewatching, fandom, and educational discovery.
- Can make use of otherwise empty space without covering the video.

Feasibility: Medium if metadata exists; low if inferred automatically.  
Distraction risk: Medium to high.  
MVP fit: Not core MVP, strong future mode.

Notes:

- Amazon Prime Video’s X-Ray is the obvious product reference point: scene-linked cast, music, trivia, and recap-style context.
- This should be a user-invoked mode, not always-on.
- The best UX may be “press/hold for scene info” rather than persistent display.
- Works best with curated metadata, not model guesses.

Implementation sources:

- timed metadata
- catalog metadata
- chapter metadata
- scene annotations
- music recognition metadata
- cast/character mappings

---

### 4. Scene Recap / “What Did I Miss?”

Use the area to show a spoiler-safe recap of recent events after pause, resume, or returning to playback.

Value:

- Helps viewers recover context without rewinding.
- Useful after interruptions.
- Useful for complex shows, dense dialogue, or second-language viewing.

Feasibility: Medium with subtitle/dialogue plus scene metadata; low if fully generative without guardrails.  
Distraction risk: Medium.  
MVP fit: Future experiment.

Notes:

- Should summarize only already-watched content.
- Should not reveal future plot.
- Best triggered on pause, resume, or explicit request.
- Amazon has moved in this direction with AI-powered X-Ray Recaps and video recaps, which shows user demand but also highlights the need for spoiler controls and accuracy.

Safer version:

- “Recent context” generated from already-shown subtitles only.
- No plot inference.
- No future scene information.

---

### 5. Character Name and Speaker Support

Show speaker identity, character names, or a small “speaking now” indicator when available.

Value:

- Helps users follow scenes with many characters.
- Helps neurodivergent viewers or viewers with face-blindness/prosopagnosia-like difficulties.
- Helps second-screen distracted viewers reorient.
- Helps when subtitles omit speaker labels.

Feasibility: Medium with script/caption metadata; low if inferred only from face/audio recognition.  
Distraction risk: Low to medium.  
MVP fit: Future accessibility mode.

Notes:

- Should rely on trusted metadata when possible.
- Model-based identity detection has privacy, accuracy, and rights concerns.
- Could be displayed only when speaker changes or when requested.

Possible UI:

```text
Speaking: Dr. Ava Brooks
```

---

### 6. Emotional Cue Assistance

Show subtle emotional or tone cues for viewers who have difficulty reading facial expressions, vocal tone, sarcasm, tension, or social cues.

Value:

- Could help neurodivergent viewers follow emotional context.
- Could help second-language viewers interpret tone.
- Could help accessibility experiences beyond traditional captions.

Feasibility: Low to medium.  
Distraction risk: Medium to high.  
MVP fit: Research only.

Notes:

- This is promising but risky.
- Emotion and sentiment inference can be wrong, culturally biased, or reductive.
- Avoid emoji-first UI. Emoji can be cute, but it may trivialize or mislabel complex emotion.
- Prefer explicit opt-in, subtle labels, and uncertainty.
- Never present inferred emotion as fact.

Safer wording:

```text
Tone: tense
Tone: playful
Tone: uncertain
```

Avoid:

```text
😡 He is angry
```

Better data sources:

- SDH captions that already include tone or sound cues.
- Curated accessibility metadata.
- Script annotations.
- User-enabled model inference with confidence labels.

---

### 7. Soundscape and SDH Enhancement

Expand SDH cues for important non-dialogue sound, music, and environmental context.

Value:

- Strong accessibility value.
- Helps deaf and hard-of-hearing viewers.
- Makes sound effects and music cues persist long enough to be understood.
- Better than cramming `[door creaks]` into a normal subtitle line.

Feasibility: High if SDH text exists; medium if inferred from audio.  
Distraction risk: Low when text-based and sparse.  
MVP fit: Strong future accessibility mode.

Examples:

```text
Sound: distant thunder
Music: tense strings rising
Off-screen: footsteps approaching
```

Notes:

- Should not invent sound cues unless model confidence is high and user opted in.
- Best when sourced from SDH captions or curated metadata.

---

### 8. Translation and Language Learning Mode

Use the lower region to show captions plus optional translation, vocabulary, romanization, or replayable phrases.

Value:

- Strong for second-language learners.
- Helps viewers compare original dialogue and translation.
- Makes repeated rewinds less necessary.

Feasibility: Medium.  
Distraction risk: Medium to high.  
MVP fit: Future opt-in mode.

Possible layouts:

```text
Now: I thought you said the bridge was closed.
Spanish: Creí que dijiste que el puente estaba cerrado.
```

Or:

```text
Japanese: ありがとう
Romaji: arigatou
English: thank you
```

Notes:

- Requires rights to subtitle/translation data.
- Machine translation can be wrong.
- Should be opt-in and probably pause-friendly.

---

### 9. Chapter, Scene, and Timeline Context

Show current chapter title, scene title, elapsed scene time, or progress within a long movie.

Value:

- Helps viewers orient themselves.
- Useful for long films, educational content, concerts, sports, and lectures.
- Less intrusive than X-Ray trivia.

Feasibility: Medium with chapter/timed metadata.  
Distraction risk: Low if minimal.  
MVP fit: Future simple enhancement.

Example:

```text
Chapter 4: The Crossing
01:12:08 / 02:18:44
```

Notes:

- Should fade or appear only on user interaction.
- Could pair well with scrubbing.

---

### 10. Playback Health Indicators

Use small unobtrusive indicators for buffer health, bandwidth, quality level, dropped frames, or stream variant.

Value:

- Useful for developers, QA, stream diagnostics, and power users.
- Helps explain playback problems without opening a debug menu.

Feasibility: High for debug builds; medium for production user UI.  
Distraction risk: Medium.  
MVP fit: Debug mode only.

Possible indicators:

```text
1080p • 6.2 Mbps • Buffer 18s
```

Or compact icons:

```text
HD | Buffer: Good | Captions: WebVTT
```

Notes:

- Great for QA.
- Bad as always-on consumer UI.
- Should be hidden behind a debug/diagnostics mode.

---

### 11. Accessibility Reading Controls

Use the extra area for caption-specific controls without covering the picture.

Value:

- Lets users tune caption experience in context.
- Avoids burying accessibility controls in menus.

Feasibility: High.  
Distraction risk: Medium if persistent, low if transient.  
MVP fit: Good companion feature.

Controls:

- caption size
- retained cue count
- retention duration
- contrast/background strength
- language track
- SDH detail level

Notes:

- Best as a transient control surface.
- On tvOS, focus handling must be carefully designed.

---

### 12. Quote Capture / Save This Line

Use the area to let viewers save recent caption text, quotes, or learning notes.

Value:

- Useful for language learning, education, research, fandom, and accessibility.
- Uses already-presented text only.

Feasibility: Medium.  
Distraction risk: Medium.  
MVP fit: Future opt-in mode.

Notes:

- Rights and sharing rules matter.
- Should not encourage large-scale subtitle extraction.
- Safer as local bookmarking than social sharing.

---

### 13. Content Warnings and Sensory Notices

Show optional scene-level warnings for flashing lights, loud sounds, violence, self-harm references, or intense sensory moments.

Value:

- Strong accessibility and safety value.
- Helps users who need sensory preparation.

Feasibility: Medium with curated metadata; low if inferred automatically.  
Distraction risk: Low if user opted in, high if unexpected.  
MVP fit: Future accessibility mode.

Notes:

- Must be opt-in.
- Must avoid spoilers when possible.
- Better before the moment than during it, but timing must be user-configurable.

---

### 14. Director / Commentary Companion

Show optional commentary notes, behind-the-scenes facts, production details, or cinematography notes.

Value:

- Strong for film enthusiasts.
- Uses empty space without interrupting playback.

Feasibility: Medium with authored metadata; low if generated.  
Distraction risk: High.  
MVP fit: Future opt-in mode.

Notes:

- Best during rewatching.
- Should not be default.
- Could pair with a “film study mode.”

---

### 15. Sports / Live Event Context

Use unused space for score, player stats, win probability, substitutions, or replay context.

Value:

- Useful for sports and live events.
- Could reduce second-screen behavior.

Feasibility: Medium to high with live data feeds.  
Distraction risk: High.  
MVP fit: Different product mode, not core Caption Theater.

Notes:

- Sports already has dense graphics.
- Must avoid covering score bugs and lower thirds.
- Better for pillarbox/letterbox cases where space is truly unused.

---

### 16. Scene Search and Jump Assistance

Use the space for “find that scene” search results while paused or scrubbing.

Value:

- Helps users locate moments by quote, character, place, or action.
- Reduces manual scrubbing.

Feasibility: Medium with transcript/scene metadata; low if fully model-generated.  
Distraction risk: Medium.  
MVP fit: Future search feature.

Notes:

- Amazon has explored AI-powered scene search on Fire TV, building on X-Ray-like metadata and model capabilities.
- Should be invoked by search, not always visible.
- Must avoid future spoilers in current playback mode.

---

### 17. Cognitive Load / Simplified Captions Mode

Offer simplified caption summaries for users who struggle with dense text.

Value:

- Could help some neurodivergent viewers, children, language learners, or viewers with cognitive load challenges.

Feasibility: Low to medium.  
Distraction risk: Medium.  
MVP fit: Research only.

Risks:

- Simplification can lose meaning.
- Generated summaries can be wrong.
- Accessibility text should not silently replace faithful captions.

Safer approach:

- Show simplified support only as an optional secondary aid.
- Keep original captions available.
- Clearly label simplified text.

---

### 18. Watch Party / Social Reactions

Use the extra area for synchronized comments, reactions, or shared notes.

Value:

- Could be fun for watch parties.
- Uses unused space without covering the movie.

Feasibility: Medium.  
Distraction risk: High.  
MVP fit: Not core.

Notes:

- High moderation burden.
- Easy to ruin immersion.
- Should be a separate social mode, not Caption Theater default.

---

### 19. Sign Language Companion Window

Use the lower or side-safe region for an optional sign-language interpretation video when available.

Value:

- Supports Deaf viewers who prefer sign language over written captions.
- Avoids covering the active picture with a picture-in-picture interpreter.
- Could make sign-language tracks easier to discover and use.

Feasibility: Medium if sign-language video tracks or sidecar assets exist; low if generated.  
Distraction risk: Medium.  
MVP fit: Future accessibility mode.

Notes:

- WCAG includes sign-language interpretation as an advanced media accessibility criterion for prerecorded audio content.
- Requires authored sign-language assets and synchronization.
- Should be user-selected, not automatic.
- The interpreter window should have size and position controls.

---

### 20. Descriptive Transcript Strip

Show a compact, synchronized descriptive transcript for already-watched content, including dialogue, important sound, and important visual context.

Value:

- Helps DeafBlind users when paired with assistive technologies.
- Helps viewers who process text better than audio/video.
- Helps users recover recent context without replaying.
- Can include visual descriptions that captions alone do not cover.

Feasibility: Medium with authored descriptive transcripts; low if generated automatically.  
Distraction risk: Medium.  
MVP fit: Future accessibility mode.

Notes:

- W3C describes descriptive transcripts as including speech, non-speech audio, and visual information needed to understand the content.
- Best triggered on pause or user request.
- Should not become a scrolling wall during normal playback.
- Could be exported to assistive display surfaces later.

---

### 21. Audio Description Now / Next Controls

Use the space to show whether audio description is available, active, and selectable, with a compact description-track control.

Value:

- Helps blind and low-vision viewers discover audio description.
- Helps families quickly toggle AD without digging into menus.
- Makes media alternatives more visible.

Feasibility: High if media selection metadata exposes AD tracks.  
Distraction risk: Low if shown transiently.  
MVP fit: Strong future control surface.

Possible UI:

```text
Audio Description: Available | On
```

Notes:

- Apple’s App Store accessibility guidance calls out support for systemwide audio-description preferences and making described content discoverable.
- Should appear when playback begins, when tracks change, or when the accessibility control surface opens.
- Should not display continuously during normal viewing.

---

### 22. Caption Style Preview and Tuning

Use the safe region as a live preview area for caption size, contrast, background opacity, font weight, and retained-cue duration.

Value:

- Lets users tune captions without obscuring the movie.
- Helps low-vision and living-room viewers find readable settings quickly.
- Reduces menu friction.

Feasibility: High for custom caption rendering.  
Distraction risk: Low when invoked from settings; medium if persistent.  
MVP fit: Strong MVP+ candidate.

Controls:

- text size
- line spacing
- contrast
- background opacity
- retained cue count
- retained cue duration
- speaker labels on/off
- SDH detail level

Notes:

- Should respect system caption preferences as a starting point.
- Could be one of the most practical uses of the space beyond persistence.

---

### 23. Reading Pace Assist

Show a subtle cue that a caption is long, dense, or about to expire, and optionally hold it longer in the retained area.

Value:

- Helps users who read more slowly or process language differently.
- Helps second-language viewers.
- Helps viewers with fatigue or cognitive load.

Feasibility: High for text-based captions.  
Distraction risk: Low if visual treatment is subtle.  
MVP fit: Strong future accessibility enhancement.

Possible UI:

```text
Long caption retained for readability
```

Notes:

- Avoid progress bars that make reading feel stressful.
- Prefer adaptive persistence over warning UI.
- Could compute reading difficulty from character count, line count, cue duration, and language.

---

### 24. Speaker Change Map

Show a lightweight speaker-change indicator or conversation map for scenes with rapid back-and-forth dialogue.

Value:

- Helps users follow overlapping dialogue.
- Helps viewers with auditory processing difficulties.
- Helps when captions lack clear speaker labels.

Feasibility: Medium with speaker-labeled captions or script metadata; low with model-only inference.  
Distraction risk: Medium.  
MVP fit: Future accessibility mode.

Possible UI:

```text
Ava → Ben → Ava
```

Notes:

- Works best when cue metadata has speaker identity.
- Should not guess identities without confidence.
- Could be useful for ensemble casts and fast comedy.

---

### 25. Plain-Language Assist

Offer optional plain-language support for complex captions, idioms, jargon, acronyms, or dense exposition.

Value:

- Helps viewers with cognitive or learning disabilities.
- Helps second-language viewers.
- Helps children or viewers unfamiliar with technical terms.

Feasibility: Low to medium.  
Distraction risk: Medium.  
MVP fit: Research only.

Possible UI:

```text
Term: injunction
Plain meaning: a court order to stop or require an action
```

Notes:

- W3C cognitive accessibility guidance emphasizes clear content, familiar patterns, and reducing memory burden.
- Should be user-requested or pause-friendly, not automatic for every phrase.
- Must not replace faithful captions silently.

---

### 26. Sensory Load Mode

Use the space for optional warnings, calming controls, and low-stimulation playback aids.

Value:

- Helps users with sensory sensitivities, migraines, vestibular issues, PTSD triggers, or anxiety around sudden intense moments.
- Gives users control before intense stimuli.

Feasibility: Medium with curated metadata; low with automatic inference.  
Distraction risk: Low when opted in; high if unexpected.  
MVP fit: Future accessibility mode.

Possible notices:

```text
Upcoming: flashing lights
Upcoming: loud sustained sound
Upcoming: intense scene
```

Notes:

- Must be opt-in.
- Timing should be configurable.
- Avoid spoilers by using category-level warnings.
- Could pair with reduced-motion UI and lower animation intensity.

---

### 27. Memory Support / Character Reminder Cards

Show a small reminder card for recurring characters, relationships, or prior context when the user asks.

Value:

- Helps viewers with memory challenges.
- Helps users returning after long breaks.
- Helps complex shows with many characters.

Feasibility: Medium with curated metadata; low with automatic inference.  
Distraction risk: Medium.  
MVP fit: Future opt-in mode.

Possible UI:

```text
Mara: Ben’s sister. Last seen leaving the station.
```

Notes:

- Should be spoiler-safe and based only on watched progress.
- Best triggered by pause or user request.
- Similar to X-Ray, but accessibility-framed around memory support.

---

### 28. On-Screen Text Translation

Use the extra area to translate signs, phones, documents, maps, or other on-screen text when that translation is available.

Value:

- Helps viewers understand visual text without covering the image.
- Useful for foreign-language scenes, fantasy/sci-fi UI, maps, and documents.
- Helps low-vision users when on-screen text is too small.

Feasibility: Medium with authored forced subtitles; low to medium with OCR/model inference.  
Distraction risk: Low to medium.  
MVP fit: Future mode.

Notes:

- Best sourced from forced subtitle tracks or curated metadata.
- OCR can be wrong and should not be the default production path.
- Should preserve timing and avoid future text.

---

### 29. Visual Description Cards

Show concise visual descriptions for important actions, expressions, gestures, or scene changes when audio description is unavailable or when the user prefers text.

Value:

- Helps blind, low-vision, DeafBlind, and cognitive-accessibility users when paired with assistive tech or large text.
- Helps users who cannot hear audio description or prefer reading.
- Helps clarify visual-only story information.

Feasibility: Medium with authored descriptive metadata; low if generated live.  
Distraction risk: Medium.  
MVP fit: Future accessibility research.

Example:

```text
Visual: Ava notices the broken lock and hides the key.
```

Notes:

- W3C describes audio description as conveying visual information needed to understand video content.
- Text visual descriptions could supplement, not replace, audio description.
- Should be synchronized and user-selected.

---

### 30. Focus Mode / Minimal UI Mode

Use the extra area only for essential access information and suppress all nonessential enrichment.

Value:

- Helps viewers who are easily distracted.
- Helps users with ADHD, cognitive load, or sensory sensitivity.
- Keeps the promise that the movie remains primary.

Feasibility: High.  
Distraction risk: Low.  
MVP fit: Strong settings concept.

Options:

- Captions only
- Captions + speaker labels
- Captions + SDH details
- Captions + accessibility controls
- No enrichment

Notes:

- Every augmentation should have an off switch.
- This could be the default for first launch.

---

### 31. Accessible Pause Summary

On pause, show a stable summary of recent captions, speaker labels, sound cues, and visual-description metadata.

Value:

- Helps users recover context after interruption.
- Lets viewers process dense scenes without rewinding.
- Helps cognitive accessibility without adding persistent playback clutter.

Feasibility: Medium with captions and metadata.  
Distraction risk: Low because it appears on pause.  
MVP fit: Future pause-specific feature.

Notes:

- Safer than always-on recap.
- Should include only already-watched content.
- Could be the best place for richer accessibility support.

---

### 32. Caption Confidence and Source Indicator

Show whether captions are authored, auto-generated, translated, SDH, forced, or unavailable.

Value:

- Helps users understand caption quality and limitations.
- Helps users choose the right track.
- Useful for accessibility trust.

Feasibility: High if track metadata exists; medium if quality labels come from providers.  
Distraction risk: Low when transient.  
MVP fit: Future control surface.

Possible UI:

```text
Captions: English SDH • Authored
```

Notes:

- Should not shame auto-generated captions, but should be transparent.
- Could appear in the accessibility control surface.

---

### 33. Assistive Device Companion Output

Use Caption Theater’s cue persistence model to feed external or companion assistive surfaces.

Value:

- Could support braille displays, companion phones, watch displays, or second-screen accessibility views.
- Helps users who need captions away from the main video image.

Feasibility: Medium to low depending on platform APIs and product scope.  
Distraction risk: Low on the main screen.  
MVP fit: Future research.

Notes:

- Keep privacy and rights constraints in mind.
- Do not export large subtitle transcripts without explicit product/legal approval.
- The same persistence window could power a companion display.

---

## Ranked Opportunity Matrix

| Idea | Value | Feasibility | Distraction | Priority |
|---|---|---|---|---|
| Persistent multi-line captions | Very high | High | Low | Core MVP |
| Large caption mode | Very high | High | Low | Core MVP / MVP+ |
| Caption style preview and tuning | Very high | High | Low-Medium | MVP+ |
| Reading pace assist | High | High | Low | MVP+ |
| SDH soundscape enhancement | High | High-Medium | Low | Strong future |
| Accessibility reading controls | High | High | Medium | Strong future |
| Audio description controls | High | High | Low | Strong future |
| Caption confidence/source indicator | Medium-High | High | Low | Strong future |
| Sign language companion window | High | Medium | Medium | Future accessibility |
| Descriptive transcript strip | High | Medium | Medium | Future accessibility |
| Visual description cards | High | Medium-Low | Medium | Future accessibility |
| Character/speaker support | High | Medium | Low-Medium | Future accessibility |
| Accessible pause summary | High | Medium | Low | Future pause mode |
| Sensory load mode | High | Medium-Low | Low-Medium | Future accessibility |
| X-Ray scene context | High | Medium | Medium-High | Future opt-in |
| Translation/language learning | High | Medium | Medium-High | Future opt-in |
| Scene recap / what did I miss | High | Medium-Low | Medium | Future opt-in |
| Memory support cards | Medium-High | Medium-Low | Medium | Future accessibility |
| On-screen text translation | Medium-High | Medium-Low | Low-Medium | Future |
| Playback health indicators | Medium | High | Medium | Debug only |
| Chapter/timeline context | Medium | Medium | Low | Future simple |
| Emotional cue assistance | Potentially high | Low-Medium | Medium-High | Research |
| Content warnings | High | Medium-Low | Low-Medium | Future accessibility |
| Plain-language assist | Potentially high | Low-Medium | Medium | Research |
| Quote capture | Medium | Medium | Medium | Future |
| Director/commentary companion | Medium | Medium | High | Rewatch mode |
| Sports/live context | High for sports | Medium | High | Separate mode |
| Scene search | Medium-High | Medium-Low | Medium | Future search |
| Simplified captions | Potentially high | Low-Medium | Medium | Research |
| Assistive device companion output | High for specific users | Medium-Low | Low | Research |
| Watch party reactions | Medium | Medium | High | Separate mode |

## Recommended Product Buckets

### Bucket 1: Caption Theater Core

These are directly aligned with the current project.

- persistent multi-line captions
- large caption mode
- retained cue history
- reading pace assist
- caption style preview and tuning
- SDH cue persistence
- caption reading controls

### Bucket 2: Accessibility Augmentations

These may provide real user value but need careful design.

- speaker identity support
- sign language companion window
- audio description controls
- descriptive transcript strip
- visual description cards
- soundscape enhancement
- content warnings and sensory notices
- emotional/tone assistance
- plain-language assist
- memory support cards
- on-screen text translation
- assistive device companion output

### Bucket 3: Contextual Enrichment

These are X-Ray-like ideas.

- cast/character context
- music identification
- trivia
- chapter/scene metadata
- director commentary
- quote capture

### Bucket 4: Diagnostics and Power Tools

Useful for developers and advanced users, but not default UX.

- buffer health
- bandwidth
- bitrate ladder / stream variant
- caption format indicator
- dropped frames
- DRM/ad state debug indicators

### Bucket 5: Separate Product Modes

These are interesting but should not be mixed into the default Caption Theater experience.

- sports/live dashboards
- watch party reactions
- scene search
- language learning mode
- film study mode

---

## What Seems Most Valuable Right Now

The strongest near-term value adds are:

1. Persistent multi-line captions.
2. Large caption mode.
3. Reading pace assist.
4. Caption style preview and tuning.
5. SDH soundscape persistence.
6. Audio description controls.
7. Caption confidence/source indicators.

These directly improve comprehension and accessibility without turning the empty region into a distracting dashboard.

The most exciting future ideas are:

1. X-Ray-style scene context.
2. Spoiler-safe “what did I miss?” recap.
3. Sign language companion window.
4. Descriptive transcript strip.
5. Translation/language learning mode.
6. Emotional/tone assistance for users who opt in.
7. Scene search while paused or scrubbing.
8. Assistive device companion output.

These could be powerful, but they require stronger metadata, trust, and UX guardrails.

---

## References

- W3C Media Accessibility User Requirements documents user needs for audio and video, including captions, audio description, transcripts, and sign language: https://www.w3.org/TR/media-accessibility-reqs/
- W3C WCAG 2.2 includes time-based media criteria for captions, audio description, sign language, extended audio description, and media alternatives: https://www.w3.org/TR/WCAG22/
- W3C transcripts guidance explains that descriptive transcripts include speech, non-speech audio, and visual information needed to understand content: https://www.w3.org/WAI/media/av/transcripts/
- W3C description guidance explains that audio description conveys visual information needed to understand video content: https://www.w3.org/WAI/media/av/description/
- W3C cognitive accessibility guidance emphasizes clear content, familiar patterns, enough time, navigation support, and personalization: https://www.w3.org/TR/coga-usable/
- Apple Media Accessibility documentation covers support for systemwide preferences for video and audio accessibility: https://developer.apple.com/documentation/MediaAccessibility
- Apple caption evaluation guidance notes that apps should support systemwide caption settings or provide equivalent/granular in-app customization: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/captions-evaluation-criteria/
- Apple audio-description evaluation guidance discusses discoverability and selection of audio description tracks: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/audio-descriptions-evaluation-criteria/
- Apple AVFoundation supports selecting subtitles and alternative audio tracks: https://developer.apple.com/documentation/avfoundation/selecting-subtitles-and-alternative-audio-tracks
- WebVTT supports cue positioning and sizing, which matters for adapting captions into a larger reading region: https://www.w3.org/TR/webvtt1/