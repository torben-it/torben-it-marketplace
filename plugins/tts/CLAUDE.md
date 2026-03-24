# tts Development Guide

## Architecture

```
tts/
├── .claude-plugin/       # Plugin manifest and marketplace config
├── commands/             # User-facing slash commands (/tts:on, /tts:off, /tts:status)
├── hooks/
│   ├── read-response.sh  # Main hook script: extracts text, calls TTS, streams audio
│   ├── stop-playback.sh  # UserPromptSubmit hook: stops playback when user types
│   └── hooks.json            # Hook registration (Stop, UserPromptSubmit, SessionStart)
├── scripts/
│   └── ensure-installed.sh  # SessionStart hook: auto-installs dependencies via uv
├── skills/tts/           # /tts skill definition (contextual guide)
├── tts/
│   ├── __main__.py       # MCP server entry point
│   ├── server.py         # FastMCP server instance
│   ├── play.py           # Audio player: reads PCM from stdin, streams via sounddevice
│   └── tools/
│       └── controls.py   # MCP tools: tts_on, tts_off, tts_status, tts_stop
└── .mcp.json             # MCP server config (used by plugin system)
```

## How it works

1. **MCP server** (`tts/`) provides toggle tools via FastMCP
2. **Stop hook** (`hooks/read-response.sh`) fires after each Claude response:
   - Checks `$CLAUDE_PLUGIN_DATA/.tts-enabled` (created/deleted by MCP tools)
   - **Loop guard**: skips if `stop_hook_active` is `true` in hook input JSON — prevents recursive triggering when the hook's own output causes another Stop event
   - Extracts `last_assistant_message` from hook JSON input
   - Strips markdown, sends to TTS API, pipes audio to `play.py`
   - Runs in background to never block Claude
3. **UserPromptSubmit hook** (`hooks/stop-playback.sh`) stops any active playback when the user starts typing
4. **SessionStart hook** (`scripts/ensure-installed.sh`) auto-installs dependencies on session start

## Development

```bash
# Run MCP server locally
uv run tts

# Test hook manually (requires CLAUDE_PLUGIN_ROOT to be set)
CLAUDE_PLUGIN_ROOT="$(pwd)" echo '{"last_assistant_message":"Hello world"}' | bash hooks/read-response.sh

# Install as plugin (from this directory)
# In Claude Code: /plugin .
```

## Config

User config: `~/.config/tts.env` (sourced by hook script).
TTS state file: `$CLAUDE_PLUGIN_DATA/.tts-enabled` (presence = enabled, defaults to `~/.claude/.tts-enabled`).

## TTS Server Requirements

Any server with OpenAI-compatible `/v1/audio/speech` endpoint returning raw PCM audio (24kHz, 16-bit, mono).
