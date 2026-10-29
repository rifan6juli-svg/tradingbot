"""Entry proses bot. Loop trading, job, dan web dibuat di langkah 15 (docs/IPD.md)."""

import argparse

from tradingbot import __version__


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="tradingbot", description="TradingBot AI (MT5)")
    parser.add_argument("--version", action="version", version=f"tradingbot {__version__}")
    parser.parse_args(argv)
    parser.print_help()
    return 0
