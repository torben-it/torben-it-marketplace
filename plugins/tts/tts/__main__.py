"""Entry point for TTS MCP server."""
from tts.server import mcp
import tts.tools  # noqa: F401 - registers tools


def main():
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
