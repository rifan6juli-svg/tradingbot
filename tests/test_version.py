import subprocess
import sys

from tradingbot import __version__


def test_version_flag_prints_version() -> None:
    result = subprocess.run(
        [sys.executable, "-m", "tradingbot", "--version"],
        capture_output=True,
        text=True,
        check=True,
    )
    assert result.stdout.strip() == f"tradingbot {__version__}"
