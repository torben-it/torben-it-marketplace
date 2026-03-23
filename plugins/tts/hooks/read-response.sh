#!/usr/bin/env bash
# read-response.sh
set -euo pipefail

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set}"

# ── Timing helpers (only active when TTS_DEBUG=1) ─────────────
_ts() { date +%s%3N; }
T_START="$(_ts)"

# ── Read hook input from stdin ──────────────────────────────────────
INPUT="$(cat)"

# ── Check if TTS is enabled ───────────────────────────────────────
STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude}"
if [ ! -f "$STATE_DIR/.tts-enabled" ]; then
  exit 0
fi

# ── Skip if TTS was just interrupted ──────────────────────────────
if [ -f "$STATE_DIR/.tts-skip-next" ]; then
  rm -f "$STATE_DIR/.tts-skip-next"
  exit 0
fi

# ── Loop guard: skip if already triggered by a Stop hook ────────────
STOP_HOOK_ACTIVE="$(echo "$INPUT" | jq -r '.stop_hook_active // false')"
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# ── Extract last assistant message ──────────────────────────────────
TEXT="$(echo "$INPUT" | jq -r '.last_assistant_message // ""')"

# Skip if empty
if [ -z "$TEXT" ] || [ "$TEXT" = "null" ]; then
  exit 0
fi

# ── Strip markdown for cleaner TTS (using -E for extended regex) ───
TEXT="$(echo "$TEXT" | sed -E \
  -e '/^```/,/^```/d' \
  -e 's/`[^`]*`//g' \
  -e 's/^#+[[:space:]]*//' \
  -e 's/\*+//g' \
  -e 's/\[([^]]*)\]\([^)]*\)/\1/g' \
  -e '/^---$/d' \
  -e '/^___$/d' \
  -e '/^\*\*\*$/d' \
  -e '/^$/N;/^\n$/d' \
  -e 's/^[[:space:]]*//;s/[[:space:]]*$//' \
  | head -c 2000)"

# Skip if nothing left after stripping
if [ -z "$TEXT" ]; then
  exit 0
fi

# ── Load user config if it exists ─────────────────────────────────────
[ -f "$HOME/.config/tts.env" ] && source "$HOME/.config/tts.env"

# ── TTS config (override via ~/.config/tts.env) ───────────────
TTS_URL="${TTS_URL:-https://tts.torbenit.online/v1/audio/speech}"
VOICE_ID="${TTS_VOICE:-4RklGmuxoAskAbGXplXN}"
MODEL="${TTS_MODEL:-eleven_multilingual_v2}"

# ── Debug logging function ────────────────────────────────────────────
_log_timing() {
  local log_dir="$HOME/.cache/tts"
  mkdir -p "$log_dir"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ── TTS timing ──" >> "$log_dir/timing.log"
}

# ── Kill any existing TTS playback before spawning new ────────────────
PID_FILE="$STATE_DIR/.tts-pid"
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  kill "$OLD_PID" 2>/dev/null || true
  rm -f "$PID_FILE"
fi

# ── Send to TTS and stream via sounddevice (in background, non-blocking)
(
  if [ "${TTS_DEBUG:-0}" = "1" ]; then
    PLAY_TIMING="$(mktemp /tmp/tts-timing.XXXXXX)"
    trap 'rm -f "$PLAY_TIMING"' EXIT

    curl -sS -X POST "$TTS_URL" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg t "$TEXT" --arg v "$VOICE_ID" --arg m "$MODEL" '{
        input: $t,
        voice: $v,
        model: $m
      }')" \
      --output - \
    | TTS_DEBUG=1 TTS_HOOK_START="$T_START" TTS_TIMING_FILE="$PLAY_TIMING" \
      uv run --directory "$PLUGIN_DIR" python -m tts.play

    _log_timing
    [ -s "$PLAY_TIMING" ] && cat "$PLAY_TIMING" >> "$HOME/.cache/tts/timing.log"
  else
    curl -sS -X POST "$TTS_URL" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg t "$TEXT" --arg v "$VOICE_ID" --arg m "$MODEL" '{
        input: $t,
        voice: $v,
        model: $m
      }')" \
      --output - \
    | uv run --directory "$PLUGIN_DIR" python -m tts.play 2>/dev/null
  fi
  # Cleanup PID file after playback finishes
  rm -f "$PID_FILE"
) </dev/null >/dev/null 2>&1 &
echo "$!" > "$PID_FILE"
disown

# Never block Claude
exit 0
