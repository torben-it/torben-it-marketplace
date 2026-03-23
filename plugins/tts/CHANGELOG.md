# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.1] - 2026-03-23

### Added
- `scripts/release.sh` — release-script der bumper version i `plugin.json` + `pyproject.toml`, opdaterer CHANGELOG, committer og tagger

## [2.0.0] - 2026-03-23
``
### Changed
- **BREAKING:** Renamed plugin from `tts-reader` to `tts`
- **BREAKING:** Renamed Python package from `tts_reader` to `tts`
- **BREAKING:** Renamed environment variables: `TTS_READER_URL` → `TTS_URL`, `TTS_READER_VOICE` → `TTS_VOICE`, `TTS_READER_MODEL` → `TTS_MODEL`, `TTS_R````EADER_DEBUG` → `TTS_DEBUG`
- **BREAKING:** Config file moved from `~/.config/tts-reader.env` to `~/.config/tts.env`
- Plugin commands now use `/tts:on`, `/tts:off`, `/tts:status`, `/tts:stop` prefix

### Added
- `/tts:stop` command and `tts_stop` MCP tool to stop playback mid-stream
- Stop-playback hook that kills audio on new user prompt

### Fixed
- TTS hook no longer blocks Claude Code during audio playback (detached background process with disown)

## [1.0.2] - 2026-03-22

### Fixed
- TTS hook no longer blocks Claude Code during audio playback (detached background process with disown)

## [1.0.1] - 2026-03-22

### Changed``
- Switched audio playback from `simpleaudio` to `sounddevice` with streaming chunks (~85ms latency)
- Unified hook config into single `hooks.json` (removed `hooks/stop.json`)
- Plugin now uses `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PLUGIN_DATA` environment variables
- Command format updated to marketplace standard (`/tts:on`, `/tts:off`, `/tts:status`)

### Added
- SessionStart hook with auto-install script (`scripts/ensure-installed.sh`)
- Debug timing support via `TTS_DEBUG` environment variable
- `TTS_STATE_DIR` environment variable for flexible state file location
- Marketplace-format command definitions (`commands/`)
- `/tts` skill definition (`skills/tts/SKILL.md`)
- README disclaimer about hosted TTS server and `the-voice-in-your-head` test model

## [1.0.0] - 2026-03-21

### Added

- Stop hook that reads Claude Code responses aloud via TTS
- MCP tools: `tts_on`, `tts_off`, `tts_status` for toggling TTS
- `/tts` skill for natural language toggle
- Markdown stripping for cleaner speech output
- User config via `~/.config/tts.env`
- Configurable TTS server URL, voice, and model via environment variables
- Non-blocking audio playback (never delays Claude)
