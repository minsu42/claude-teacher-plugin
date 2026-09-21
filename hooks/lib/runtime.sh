#!/bin/bash
# Loading this file only defines functions. Checks run when explicitly called.
# Checks use installed tools only; they never download or install software.

teach_jq_available() {
  command -v jq >/dev/null 2>&1 || return 1

  # Review reminders need JSON parsing and calendar-date support.
  # Expected errors from missing/broken runtimes must not interrupt a lesson.
  printf '{}' | TZ=UTC jq -e '
    type == "object" and (
      "2026-03-09"
      | strptime("%Y-%m-%d")
      | mktime
      | strftime("%Y-%m-%d") == "2026-03-09"
    )
  ' >/dev/null 2>&1
}

teach_python_available() {
  local python_path
  python_path=$(command -v python3) || return 1

  # Apple's placeholder may offer to install developer tools. Do not trigger it.
  if [[ "$OSTYPE" == darwin* && "$python_path" == /usr/bin/python3 ]]; then
    /usr/bin/xcode-select -p >/dev/null 2>&1 || return 1
  fi

  # -I ignores project/user Python modules; -B prevents bytecode cache writes.
  python3 -I -B -c '
import datetime
import json
import sys

sys.exit(sys.version_info < (3, 8))
' >/dev/null 2>&1
}

teach_detect_runtime() {
  TEACH_JSON_RUNTIME=""

  if teach_jq_available; then
    TEACH_JSON_RUNTIME=jq
    return 0
  fi

  if teach_python_available; then
    TEACH_JSON_RUNTIME=python3
    return 0
  fi

  return 1
}
