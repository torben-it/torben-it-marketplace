"""TTS control tools."""
import os
import signal
import subprocess
from pathlib import Path

from tts.server import mcp

_raw = os.environ.get("TTS_STATE_DIR", "")
STATE_DIR = Path(_raw) if _raw and not _raw.startswith("$") else Path.home() / ".claude"
STATE_DIR.mkdir(parents=True, exist_ok=True)
STATE_FILE = STATE_DIR / ".tts-enabled"


@mcp.tool()
def tts_on() -> str:
    """Enable TTS - Claude Code responses will be read aloud."""
    STATE_FILE.touch()
    return "TTS enabled - responses will be read aloud."


@mcp.tool()
def tts_off() -> str:
    """Disable TTS - Claude Code responses will not be read aloud."""
    STATE_FILE.unlink(missing_ok=True)
    return "TTS disabled - responses will not be read aloud."


@mcp.tool()
def tts_status() -> str:
    """Check if TTS is currently enabled or disabled."""
    if STATE_FILE.exists():
        return "TTS is currently enabled."
    return "TTS is currently disabled."

@mcp.tool()
def tts_stop() -> str:
    """Stop TTS playback - Player will be terminated."""
    pid_file = STATE_DIR / ".tts-pid"
    if pid_file.exists():
        try:
            pid = int(pid_file.read_text().strip())
            os.kill(pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError, ValueError):
            pass
        pid_file.unlink(missing_ok=True)
    # Fallback: pattern match kill
    subprocess.run(["pkill", "-f", "python -m tts.play"], capture_output=True)
    return "TTS stopped - the rest is silence."
