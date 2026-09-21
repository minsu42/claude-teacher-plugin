#!/bin/bash
# PostToolUse (Edit|Write): prompt Claude to review the student's code by asking
# questions rather than correcting it.

HOOK_INPUT=$(cat)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/teach-guard.sh
. "$SCRIPT_DIR/lib/teach-guard.sh"

# Extra hook reminders are optional; project instructions handle the lesson too.
teach_detect_runtime || exit 0

teach_is_learning_project "$HOOK_INPUT" || exit 0

SOURCE_FILE=$(printf '%s' "$HOOK_INPUT" | teach_json source-file 2>/dev/null)
[ -z "$SOURCE_FILE" ] && exit 0

# Prose, config, diagrams and education-DB writes are not the student's code.
case "/${SOURCE_FILE#/}" in
  */.claude/*|*/.local/share/claude-education/*|*/node_modules/*|*/.git/*|*/docs/*)
    exit 0
    ;;
esac
DB_DIR=$(teach_db_dir) || exit 0
case "$SOURCE_FILE" in
  "$DB_DIR"/*)
    exit 0
    ;;
esac
case "$SOURCE_FILE" in
  *.py|*.js|*.jsx|*.ts|*.tsx|*.c|*.h|*.cc|*.cpp|*.hpp|*.cs|*.java|*.go|*.rs|\
  *.rb|*.php|*.swift|*.kt|*.scala|*.sh|*.sql|*.lua|*.r|*.R)
    ;; # Source file: continue to the exercise reminder.
  *)
    exit 0
    ;;
esac

CONTEXT=$(cat <<'CONTEXT'
Claude just edited a source file. This event does not observe the student's editor. If
this change belongs to a learning exercise, explain the change and ask one relevant
reasoning or edge-case question. Let the student implement the next exercise step; skip
this reminder for setup or teaching artifacts.
CONTEXT
)
teach_emit_context "PostToolUse" "$CONTEXT"

exit 0
