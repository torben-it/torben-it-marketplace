"""Streaming audio player: reads raw PCM chunks from stdin and plays via sounddevice."""
import os
import signal
import sys
import time

import sounddevice as sd

CHUNK_SIZE = 4096  # ~85ms audio at 24kHz/16-bit/mono

_stop = False


def _handle_signal(signum, frame):
    global _stop
    _stop = True


def main():
    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    debug = os.environ.get("TTS_DEBUG") == "1"
    hook_start_ms = int(os.environ.get("TTS_HOOK_START", "0"))
    timing_file = os.environ.get("TTS_TIMING_FILE", "")
    now_ms = 0
    with sd.RawOutputStream(samplerate=24000, channels=1, dtype="int16") as stream:
        while not _stop:
            chunk = sys.stdin.buffer.read(CHUNK_SIZE)
            if not chunk:
                break
            if not now_ms:
                now_ms = int(time.time() * 1000)
            stream.write(chunk)

    if debug and now_ms and timing_file and hook_start_ms:
        ttfa_hook = now_ms - hook_start_ms
        with open(timing_file, "w") as f:
            f.write(f"  ttfa_hook:     {ttfa_hook}ms  (hook fire → first audio)\n")


if __name__ == "__main__":
    main()
