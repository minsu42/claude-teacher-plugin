# Changelog

## 1.10.0

- Start lessons after a topic and starting-level question; skip answers already supplied and leave personal preferences optional for later.
- Remove the required runtime check and manual-mode handoff from onboarding. Keep the runtime script as an optional diagnostic and do not ask learners to install helper tools.
- Include loading progress, saving new learning, and ending lessons in the managed project instructions, whether or not hook reminders run. Recognize ordinary requests such as “save this” and “I'm done for today.”
- Keep validation, permission handling, and truthful save reporting in the shared data contract. These routines depend on Claude following the instructions and completing its file operations; hook tests do not establish end-to-end teaching reliability.
- Update the README with installation inside Claude Code, the shorter onboarding flow, and the remaining platform limits of the optional Bash hooks. Existing users can rerun init-edu to refresh their managed teaching block without resetting history.

## 1.9.4

- Sync the README with runtime fallback, manual saving, explicit hook checks, and the hook review guide. Clarify checkpoint requests, review summaries, repeat setup, and development dependencies.

## 1.9.3

- Make runtime checks explicit in each event script; loading helpers no longer runs checks or exits the hook.
- Expand JSON operations, review formatting, and teaching instructions for manual review. Use descriptive names and limit Python exception handling to expected input and file errors.
- Add a hook code guide covering entry points, data access, output, and failure handling, plus readability rules for future changes.

## 1.9.2

- Make jq optional when Python 3.8+ is already installed. Probe JSON capabilities and use the Python standard library when jq is missing or broken; no packages are downloaded or installed.
- Check automatic-feature support during onboarding and repeat setup. Explain manual saving when support is unavailable and preserve that limitation in the project's teaching instructions.
- Keep project opt-in, malformed-input handling, review limits, and checkpoint loop protection on both JSON backends. Run Python in isolated mode without writing cache files, and process the topic queue in one Python invocation.
- Add regression coverage for both backends, unavailable/broken tools, escaped labels, Python import isolation, and a 500-topic review queue.

## 1.9.1 — 2026-09-06

### Fixes

- Preserve existing project instructions, output styles, unrelated hook handlers, and student history during setup. Setup and reset are explicit user commands. Keep personal profile data out of shared project instructions by default.
- Resolve the same `CLAUDE_TEACHER_DB` path in every skill and hook; use cache-safe paths for bundled resources and namespaced skill commands.
- Use unique quiz attempt IDs and idempotent merge instructions. Preserve review dates during passive engagement and repeated saves; exclude planned, untaught topics from review queues.
- Validate hook inputs and markers, honor explicit opt-out, skip subagent activity, and handle corrupt DB records without overwriting them.
- Calculate overdue calendar days without DST errors and cap injected review lists. Avoid attributing Claude's tool calls or infrastructure failures to the student.
- Treat Stop as the end of a response, with one guarded checkpoint continuation. Remove unreliable English save-phrase detection and avoid duplicate session-end events.
- Fix demo progress updates, isolated/optional local storage, idle animation work, keyboard handling, fullscreen fallback, canvas pill opacity, narrow-screen header layout, and accessible controls. Show an explanation when CDN libraries fail to load.
- Fix Anki metadata headers so field names are not imported as a card. Remove unsourced “verified” motivational fallbacks and answer-revealing quiz option descriptions.
- Make Excalidraw JSON examples parseable and supply the missing target label. Resolve conflicting roadmap palette/container guidance.

### Maintenance

- Move repository-only developer guidance to `.claude/CLAUDE.md`; use a separate onboarding template and shared education-data reference for runtime instructions.
- Add focused hook and demo regression checks. Validate the plugin manifest and marketplace separately.
- Align integration with the current official [plugins](https://code.claude.com/docs/en/plugins-reference), [hooks](https://code.claude.com/docs/en/hooks), and [skills](https://code.claude.com/docs/en/skills) documentation. Retain documented exec-form `args` and Stop `additionalContext` support.

### Validation and limits

- Both manifests pass Claude Code 2.1.260 strict validation; its component inventory discovers 15 skills and 5 hooks.
- Local hook coverage includes malformed input, project isolation, custom/cache paths containing special characters, DST, review limits, and loop prevention. Demo checks cover storage and drawing behavior.
- A generated five-step demo was checked in the browser for playback/progress, navigation, reset, restored step, light/dark themes, and narrow-screen layout, with no console errors.
- Tutoring, onboarding, and data-merge instructions still depend on Claude following the skills. A full multi-turn student session and simultaneous DB writers are not covered by deterministic tests. Hooks cannot guarantee saving after interruption, permission denial, or an API failure.
