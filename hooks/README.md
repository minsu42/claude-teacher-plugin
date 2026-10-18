# Reading the hook code

Start with [hooks.json](hooks.json). It lists the five events and the Bash
script Claude Code runs for each. Every hook is registered in the shell form
(`"command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/<script>.sh\""`) rather than
the exec form (`"command": "bash"` with a separate `args` list). Claude Code
runs the shell form through Git Bash on Windows, whereas the exec form resolves
`bash` on `PATH`, where `C:\WINDOWS\system32\bash.exe` (the WSL launcher) is
usually found before Git Bash and cannot open a Windows path, so the hook exits
with status 127. The script path is quoted so plugin cache paths containing
spaces still work.

Each event script follows the same order:

1. Read the event's JSON from stdin and load the local helper definitions.
2. Explicitly check for a working jq or Python installation.
3. Validate the event and check whether this project enables teaching.
4. Apply the event's filters, such as the checkpoint loop guard.
5. Print JSON containing context for Claude.

## Event scripts

| Script | Reads and checks | Context sent to Claude |
| --- | --- | --- |
| [session-start-load-db.sh](session-start-load-db.sh) | Student profile, dashboard, and topic records | A bounded review summary or guidance about missing/corrupt records |
| [inject-teach-context.sh](inject-teach-context.sh) | Project opt-in and event validity | Tutor-mode instructions written directly in the script |
| [post-code-review.sh](post-code-review.sh) | The changed path and source-file exclusions | A prompt to ask a relevant exercise question |
| [post-quiz-motivate.sh](post-quiz-motivate.sh) | The failed command, error, and cancellation flag | A prompt to help with exercise failures; command text is never executed |
| [stop-save-progress.sh](stop-save-progress.sh) | Dashboard validity, assistant message presence, and loop guard | A request for Claude to checkpoint unsaved learning evidence |

The Stop script requests a save; it does not write student records itself.
Claude carries out that request through the save-progress skill, subject to
permissions and the skill's rules.

## Shared helpers

- [teach-guard.sh](lib/teach-guard.sh) checks project opt-in, ignores subagent
  events, resolves the education database path, and formats context output.
- [runtime.sh](lib/runtime.sh) checks installed jq and Python capabilities.
  It avoids invoking Apple's Python placeholder when developer tools are absent.
- [json.sh](lib/json.sh) lists every supported JSON operation explicitly. It
  uses jq or passes the operation to [json_fallback.py](lib/json_fallback.py).
- [review-context.jq](lib/review-context.jq) builds the jq review summary.
  The Python fallback has named functions for the same calculation.

Loading a shell helper only defines functions and loads other local helpers.
It does not run runtime checks or exit the caller. The Python fallback uses
the standard library; `-I` isolates imports and `-B` prevents cache-file writes.

## Data access and failures

The hooks read the event payload, the project's `.claude/claude-teacher.json`
marker (or legacy `memory/knowledge_gaps.md` existence), and relevant JSON files
in the education database. The database defaults to
`~/.local/share/claude-education`; `CLAUDE_TEACHER_DB` can select an absolute path.
Project selection uses `CLAUDE_PROJECT_DIR`, then the event's `cwd`, then the
current working directory.

The shipped hook code makes no network requests, installs no software, and
does not write student files. The session summary sent to Claude includes
student and topic labels; these are marked as data and bounded in length.
Other event instructions are literal text in their scripts. JSON input is
parsed as data; it is never evaluated as shell or Python code.

Malformed data, disabled projects, and unavailable runtimes are normal skip
conditions. Shell helpers return a status and the event script decides whether
to stop. Expected parser errors are quiet to avoid interrupting a lesson.
Python programming errors are left visible for diagnosis.

[check-runtime.sh](check-runtime.sh) is an optional read-only diagnostic, separate
from event hooks and normal onboarding. It reports hook-helper availability;
the project lesson instructions handle loading progress and requesting saves
even without these reminders. It does not verify that a save occurred.
The [hook tests](../tests/test_hooks.py) exercise jq and Python separately.
