#!/bin/bash
# PostToolUseFailure (Bash): offer encouragement when the student's code fails.
#
# A Bash command that exits non-zero raises PostToolUseFailure, not PostToolUse,
# and the payload carries the failure in a top-level `error` string — there is no
# tool_response object on this event.

HOOK_INPUT=$(cat)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/teach-guard.sh
. "$SCRIPT_DIR/lib/teach-guard.sh"

# Extra hook reminders are optional; project instructions handle the lesson too.
teach_detect_runtime || exit 0

teach_is_learning_project "$HOOK_INPUT" || exit 0

FAILED_COMMAND=$(printf '%s' "$HOOK_INPUT" | teach_json command 2>/dev/null)
FAILURE_MESSAGE=$(printf '%s' "$HOOK_INPUT" | teach_json error 2>/dev/null)
WAS_INTERRUPTED=$(printf '%s' "$HOOK_INPUT" | teach_json interrupt)

# A cancelled command is not a failed attempt.
[ "$WAS_INTERRUPTED" = "true" ] && exit 0
[ -z "$FAILURE_MESSAGE" ] && exit 0

# Housekeeping commands the tutor runs itself, not the student's work.
# Only skip simple housekeeping. A compound command may run student tests.
# These are string patterns for classification; this hook never runs the command.
case "$FAILED_COMMAND" in
  *'&&'*|*';'*|*'|'*|*$'\n'*) ;;
  git|git\ *|mkdir\ *|curl\ *|jq\ *|cat\ *|ls|ls\ *|cd\ *|echo\ *|rm\ *|npm\ install*|pip\ install*) exit 0 ;;
esac

# The existing tool result already contains the error. Do not repeat arbitrary
# command output as plugin instructions, or assume Claude's failure is theirs.
CONTEXT=$(cat <<'CONTEXT'
A Bash tool call failed. If it ran the student's exercise or tests, help them reason
through the error with one hint at a time. For repeated difficulty, offer specific
encouragement via /claude-teacher:motivate. Diagnose setup, network, permission, or tool
failures normally; do not count those as student misconceptions.
CONTEXT
)
teach_emit_context "PostToolUseFailure" "$CONTEXT"

exit 0
