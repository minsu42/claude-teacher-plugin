#!/bin/bash
# Optional read-only diagnostic; normal onboarding does not run this check.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/runtime.sh"
if teach_detect_runtime; then
  printf 'Extra hook reminders can run (%s). No extra installation is needed.\n' "$TEACH_JSON_RUNTIME"
else
  cat <<'STATUS'
Extra hook reminders are unavailable: no working jq or Python 3.8+ was found on PATH.
Lessons can continue without installing anything. Project instructions tell Claude
to load progress and save new learning through the teaching skills.
You can also say "save this" or "I'm done for today".
This check does not verify that any progress has been saved.
STATUS
  exit 1
fi
