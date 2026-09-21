#!/bin/bash
# SessionStart: summarize the profile and a bounded queue of studied topics.

HOOK_INPUT=$(cat)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/teach-guard.sh
. "$SCRIPT_DIR/lib/teach-guard.sh"

# Extra hook reminders are optional; project instructions handle the lesson too.
teach_detect_runtime || exit 0

teach_is_learning_project "$HOOK_INPUT" || exit 0

DB_DIR=$(teach_db_dir) || exit 0
TODAY=$(date +%Y-%m-%d)

if [ ! -f "$DB_DIR/student.json" ]; then
  CONTEXT=$(cat <<'CONTEXT'
This is a learning project without a student profile.
Suggest /claude-teacher:init-edu to finish onboarding.
CONTEXT
)
  teach_emit_context "SessionStart" "$CONTEXT"
  exit 0
fi
if ! STUDENT_PROFILE=$(teach_read_object "$DB_DIR/student.json"); then
  CONTEXT=$(cat <<'CONTEXT'
The student profile could not be read as a JSON object.
Preserve the file and help recover it; do not overwrite or reset it automatically.
CONTEXT
)
  teach_emit_context "SessionStart" "$CONTEXT"
  exit 0
fi

DASHBOARD='{}'
if [ -f "$DB_DIR/dashboard.json" ]; then
  if ! DASHBOARD=$(teach_read_object "$DB_DIR/dashboard.json"); then
    CONTEXT=$(cat <<'CONTEXT'
The education dashboard could not be read as a JSON object.
Preserve it and recover from topic and quiz records before saving.
CONTEXT
)
    teach_emit_context "SessionStart" "$CONTEXT"
    exit 0
  fi
fi

# Read each topic once. Skip corrupt records without losing valid ones.
REVIEW_CONTEXT=$(teach_json review-files \
  "$DB_DIR/topics" "$TODAY" "$STUDENT_PROFILE" "$DASHBOARD") || exit 0
teach_emit_context "SessionStart" "$REVIEW_CONTEXT"
