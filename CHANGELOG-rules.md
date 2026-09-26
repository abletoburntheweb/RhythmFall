# CHANGELOG Rules

This document defines how `CHANGELOG.md` must be maintained. The existing `CHANGELOG.md` is the primary style authority — its wording, structure, granularity, and level of detail take precedence over any generic template.

## Language

- `CHANGELOG.md` must contain English text only.
- Never add Russian prose, headings, comments, or mixed-language changelog text.
- Technical identifiers may remain unchanged when genuinely necessary, but all surrounding prose must be English.

## Purpose

- `CHANGELOG.md` is a user-facing product release changelog, not an internal development log, QA report, implementation diary, or commit history.
- Describe what changed for the user:
  - new features
  - new capabilities
  - changed behavior
  - meaningful improvements
  - important fixes
  - useful player-facing limitations or notes
- Describe **what** changed, not unnecessary details about **how** the code implements it.

## Main Style Reference

Before editing the changelog:

- Read the existing `CHANGELOG.md`.
- Read the target version being updated.
- Read `v1.2.0` and other established, well-written versions as style references.
- Prefer the existing changelog's wording, structure, granularity, and level of detail over inventing a new style.

The existing changelog is the primary style authority. The rules in this file define principles; they do not replace the existing project's writing style.

## Classify against the feature's release history, not merely the previous release

Study the history of the specific feature across **all previous released versions** in `CHANGELOG.md` before classifying.

- If a feature or capability has **never existed in any released version** and appears in the current version → `### New`.
- If a feature **already existed in any previous released version** → changes to it are usually `### Fixes & Improvements` when they are improvements, fixes, or behavior changes to that existing feature.
- When a feature is introduced for the first time in the current version and many problems were fixed during its development, do **not** turn those development fixes into separate `Fixes & Improvements` entries. Describe them as part of the new feature in `### New`.
- Do not decide based only on whether the feature was in the immediately previous release. Use all previous versions to understand the feature's history and status, and use the current version to describe what changed now.

### New

Put a feature in `### New` when the feature or capability has **never existed in any previous released version**.

This remains true even if implementing the new feature required many bug fixes during development.

Do **not** turn development problems of a newly introduced feature into `Fixes & Improvements`.

For example, if Chart Editor as a whole appears for the first time in the current version, it and all of its initial capabilities (pencil behavior, selection, quantization, inspector, mouse interaction, undo/redo, MIDI Pattern support, Test Play) belong in `### New` as capabilities of that new feature, not as a list of development fixes.

### Fixes & Improvements

`### Fixes & Improvements` is for functionality that **already existed in any previous released version**.

Use it for:

- bug fixes to existing features
- improvements to existing features
- behavior refinements
- usability improvements
- performance improvements when user-visible
- corrections to existing systems
- new capabilities inside an already existing feature

The key question is:

> Has this feature or capability ever existed in any released version before?

- If **no** → `New` (the whole feature is new in this version).
- If **yes** → `Fixes & Improvements` when the change is a fix, improvement, or change to that existing feature — even if the specific sub-capability appears for the first time in the current version.

Example:

- If Chart Editor first appeared in `v1.2.0`, it is already an existing feature in `v1.2.1`. Improvements to Chart Editor in `v1.2.1` therefore belong in `### Fixes & Improvements`, even if a specific capability inside Chart Editor appears for the first time in `v1.2.1`.
- If Chart Editor as a whole appears only in `v1.2.1` and did not exist before, it and all of its initial implementation belong in `### New`.

Important distinctions:

- New feature as a whole → `New`.
- New capability inside an already existing feature → usually `Fixes & Improvements` (improvement of the existing feature).
- Bug fix of an existing feature → `Fixes & Improvements`.
- Development bug while creating a new feature → not a separate `Fixes & Improvements` entry; describe it as part of the `New` feature.

Do not classify something as a "fix" merely because the implementation involved fixing bugs while developing a brand-new feature.

## Current Version Cleanup

When asked to clean up or rewrite the current version, existing entries may be rewritten, merged, removed, or replaced when necessary to make the release changelog consistent with the project's established style.

- Only the current version may be cleaned in this way unless explicitly instructed otherwise.
- Do not rewrite older released versions merely to make them stylistically consistent.
- When cleaning the current version:
  - preserve meaningful user-facing information
  - remove unnecessary implementation details
  - rewrite technical descriptions into product-level descriptions
  - do not aggressively shorten a large feature
  - do not remove useful capabilities simply because the original text was too technical

The goal is rewrite, not information loss.

## Do Not Artificially Shorten Large Releases

A large changelog is completely acceptable for a large release.

- Do not reduce a large feature to a vague one-line summary merely because a shorter changelog looks cleaner.
- Preserve meaningful details about what users can actually do.
- If a feature has many important capabilities, describe them.
- The changelog may be detailed when the release is detailed.

## Avoid Implementation Details

Do not normally include:

- `.gd` filenames
- internal function names
- internal class names
- variable names
- signal connections
- debounce timings
- internal node paths
- debug logging
- headless tests
- runtime QA
- diagnostic scripts
- internal file paths
- hashes
- internal state machines
- implementation-specific constants
- source-code expressions
- internal architecture details
- "final QA pass" style development language

Example of what **not** to write:

```
set_pattern_ghost(Color(0.6,0.85,1.0))
```

```
logic/data/rhythm_dna_view.gd:coalesce_to_semantic_sections()
```

unless such a technical reference is genuinely necessary for the user to understand the product change. Instead describe the resulting user-facing behavior.

## Preserve Useful Information When Rewriting Technical Entries

When an existing entry contains useful product information mixed with technical implementation details, do **not** simply delete the whole entry. Extract the user-facing meaning and rewrite it.

For example, a technical description such as:

> Semantic sections for Practice with implementation rules, internal confidence values, block names, thresholds, and internal abbreviations

should become a clear description of the resulting Practice behavior:

- what semantic sections are now recognized
- how sections are grouped or displayed when relevant
- what meaningful behavior the player sees

Do not expose internal implementation rules merely because they were present in the original text.

The same principle applies to onboarding state, Practice HUD, RR What-if, Chart Editor, MIDI Patterns, Test Play, and any other feature. For example:

- Do not expose internal `settings.json` fields when the useful information is simply that onboarding progress is now remembered.
- Do not expose `practice_bests.json` when the useful information is that Best Practice is saved per chart.
- Do not expose an internal RR function name when the useful information is that the What-if calculation uses the same rating logic as the actual rating.

Preserve the meaningful product behavior, not the implementation vocabulary.

## UI Changes: Describe Result, Not Implementation

Do not describe internal UI implementation in `CHANGELOG.md`, such as replacing one UI component or hint type with another.

- If a hint or UI change has user value and is worth mentioning, describe the **result for the user**, for example: `RhythmDNA now uses the standard hint with the available actions/controls.`
- Do not mention internal UI component names, classes, scenes, functions, node paths, or other implementation details.
- Do not delete useful user information only because the original implementation description was technical: rewrite the technical description into a user-facing formulation.

This continues the same principle of preserving user-facing meaning while removing implementation noise.

## Group Related Changes

Keep related functionality together.

- If a feature already has a section, add new information to that existing section instead of creating another section for the same feature.
- For example, if Chart Editor already exists: add later Chart Editor improvements to that existing Chart Editor section; do not create `Chart Editor Improvements`, `New Chart Editor`, or multiple disconnected Chart Editor sections.
- One evolving product feature should have one coherent changelog history.

## Group by Coherent Product Entities

Changelog must be organized by coherent user-facing product entities, not by internal tasks, tickets, or subtasks.

- If several changes relate to the same feature or product entity, they must be described under one common heading for that entity.
- Do not create separate headings for separate capabilities if they are parts of the same feature.
- If a heading for that entity already exists, add related information there instead of creating a new heading.
- This rule applies to all features and changes, not only Replay.
- For example, if Replay is one new feature in the current version, then Watch Replay from Victory, Watch Replay from Results, binding a replay to its exact run, and handling of a missing or deleted replay must all be described inside the single `Replay` section, not as multiple separate changelog entries.
- Similarly, Practice Mode must be a single entity with its related capabilities described together inside it.
- The same applies to Chart Editor, Library, Rhythm DNA, Navigation, and any other entity: if changes belong to one coherent product entity, group them together.
- The goal is a changelog organized by coherent product entities, not by implementation tasks, tickets, or individual capabilities.

## Feature vs Capability

- A completely new product feature belongs in `### New`.
- A new capability added to an already released feature belongs in `### Fixes & Improvements`.
- A change to an existing capability also belongs in `### Fixes & Improvements`.
- Development bugs encountered while creating a completely new feature remain part of that feature's `### New` entry rather than becoming separate fixes.
- The appearance of a new capability does not make an already-existing feature a new feature.

## Classification by the Actual User-Facing Subject

- Do not classify an entry based only on its heading or where the change is mentioned.
- Classify it according to what user-facing product behavior actually changed.
- For example, a change to a system remains a change to that system even if the same information is also described or displayed elsewhere.
- A navigation, article, presentation, or usability change that is specific to a surface belongs to that surface.
- An article describing another game system does not automatically make that system the subject of the change.

## Naming Does Not Define an Entity

- Different headings do not necessarily represent different product entities.
- Similar or differently worded headings describing the same evolving feature should normally be consolidated.
- Conversely, similarly named headings should not be merged when they represent genuinely different user-facing product entities.
- Determine entity boundaries from user-facing functionality and behavior, not from heading names alone.

## Heading Granularity

- Do not create a separate heading merely because a feature has a new aspect, capability, or type of improvement.
- If the change belongs to an existing coherent entity, add it to that entity's existing section.
- Create a separate heading only when the change represents a meaningfully distinct product entity.

## Avoid Artificial Grouping

- Do not merge unrelated changes merely because they occur on the same screen, in the same menu, or during the same workflow.
- A single screen can contain multiple independent product entities.
- Group related changes by the actual entity that changed, rather than by physical UI location or implementation task.

## Performance Changes

- Performance improvements should normally be grouped with the feature or product entity whose user-facing performance was improved.
- A shared `Performance` section may be used when several meaningful performance improvements affect clearly different product areas and the existing changelog style supports a cross-feature summary.
- Do not create separate performance headings for minor improvements to the same feature.
- Do not use a global `Performance` section merely to avoid deciding which product entity an improvement belongs to.

## Historical Classification Clarification

- The exact wording or exact sub-capability does not need to have appeared in an earlier release for the underlying feature to count as existing.
- If the underlying user-facing feature already existed in any released version, later additions, extensions, or refinements to that feature are normally `Fixes & Improvements`.
- Always distinguish between introducing the feature itself and extending an already-existing feature.

## Preserve Existing Structure

Do not unnecessarily reorganize `CHANGELOG.md`.

When adding information:

- extend existing sections when possible
- preserve established headings
- preserve useful ordering
- merge related information where appropriate
- do not split sections merely because a feature became large

## Version Placement

- When asked to update a particular version, modify that version.
- Do not create a new version unless explicitly requested.

## No Documentation References

Do not add:

- "See documentation"
- "See another changelog"
- links to internal docs
- references to implementation documents
- references to diagnostic files
- references to test scripts

Work from the existing project changelog and the actual user-facing changes.

## Recommended Structure

Follow the existing project's established structure, but a typical release may look like:

```md
## RhythmFall Client vX.X.X

Short release summary.

### New

Feature

- User-facing capability.
- User-facing capability.

Another Feature

- User-facing capability.

### Fixes & Improvements

Existing Feature

- User-facing fix or improvement.

### Notes

- Only genuinely useful player-facing notes.
```

Do not force every release to have exactly these sections if the existing changelog uses a different structure.

## Final Review

Before finishing any changelog update, verify:

- Is all prose in English?
- Was the history of each feature checked across all previous released versions in `CHANGELOG.md` before classifying?
- Are features that never existed in any previous released version under `New`?
- Are fixes and improvements limited to features that already existed in any previous released version (including new capabilities inside an existing feature)?
- Were development bugs of a newly introduced feature incorrectly turned into separate `Fixes & Improvements` instead of being described as part of `New`?
- Were related changes added to their existing feature section?
- Was useful user-facing information preserved?
- Were unnecessary implementation details removed?
- Does the result resemble `v1.2.0` and the project's established style?
- Is the changelog detailed enough for the size of the release?
- Was the current version cleaned when necessary, without rewriting older versions?
- Does the final text read like a product release changelog rather than an engineering report?

## Most Important Principle

Keep the useful information, remove the implementation noise, classify changes against the feature's release history across all previous versions — not merely the previous release — and write the result in the established user-facing style of this project's changelog.
