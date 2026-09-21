#!/bin/bash
# Fixed JSON operations. Input values are data, never executable expressions.
# Loading helpers does not run checks or exit the calling hook.
. "$SCRIPT_DIR/lib/runtime.sh"

teach_json() {
  if [ "$TEACH_JSON_RUNTIME" = python3 ]; then
    # Isolated mode ignores PYTHONPATH, user packages, and the working directory.
    python3 -I -B "$SCRIPT_DIR/lib/json_fallback.py" "$@"
    return $?
  fi

  if [ "$TEACH_JSON_RUNTIME" != jq ]; then
    return 1
  fi

  local operation="$1"
  shift
  case "$operation" in
    cwd)
      jq -r '.cwd | select(type == "string")'
      ;;
    main-payload)
      jq -se '
        length == 1 and (.[0] | type == "object" and .agent_id == null)
      ' >/dev/null
      ;;
    marker)
      jq -se '
        length == 1 and (
          .[0] | type == "object" and ((has("enabled") | not) or .enabled == true)
        )
      ' "$1" >/dev/null
      ;;
    object)
      jq -ecs '
        if length == 1 and (.[0] | type == "object") then
          .[0]
        else
          empty
        end
      ' "$1"
      ;;
    emit)
      jq -n --arg event "$1" --arg context "$2" '{
        hookSpecificOutput: {
          hookEventName: $event,
          additionalContext: $context
        }
      }'
      ;;
    source-file)
      jq -r '.tool_input.file_path | select(type == "string")'
      ;;
    command)
      jq -r '.tool_input.command | select(type == "string")'
      ;;
    error)
      jq -r '.error | select(type == "string")'
      ;;
    interrupt)
      jq -r '.is_interrupt // false'
      ;;
    stop-active)
      jq -r '.stop_hook_active // false'
      ;;
    has-message)
      jq -e '.last_assistant_message | type == "string" and length > 0' >/dev/null
      ;;
    review-files)
      local directory="$1" today="$2" profile="$3" dashboard="$4"
      local topic_file

      for topic_file in "$directory"/*.json; do
        [ -f "$topic_file" ] || continue
        teach_json object "$topic_file" || continue
      done | TZ=UTC jq -sr \
        --arg today "$today" \
        --argjson profile "$profile" \
        --argjson dashboard "$dashboard" \
        -f "$SCRIPT_DIR/lib/review-context.jq"
      ;;
    *)
      return 1
      ;;
  # Invalid JSON is expected input: return failure without interrupting Claude.
  esac 2>/dev/null
}
