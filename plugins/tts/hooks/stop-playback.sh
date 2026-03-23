#!/usr/bin/env bash
# stop-playback.sh — Kill any running TTS playback (called by UserPromptSubmit hook)
set -euo pipefail

STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude}"
PID_FILE="$STATE_DIR/.tts-pid"

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    # Signal read-response.sh to skip TTS for the next response
    touch "$STATE_DIR/.tts-skip-next"
  fi
  rm -f "$PID_FILE"
fi

# Fallback: pattern match kill
pkill -f "python -m tts.play" 2>/dev/null || true

exit 0
