"""Tes statis untuk scripts/setup_vps.ps1 (F-10). Skrip dijalankan sungguhan di VPS (langkah 1a)."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "setup_vps.ps1"
ENV_EXAMPLE = ROOT / ".env.example"


def code_lines() -> list[str]:
    text = SCRIPT.read_text(encoding="ascii")
    text = re.sub(r"<#.*?#>", "", text, flags=re.DOTALL)
    return [line for line in text.splitlines() if not line.lstrip().startswith("#")]


def test_script_is_ascii_for_powershell_5() -> None:
    SCRIPT.read_bytes().decode("ascii")


def test_no_powershell_7_only_operators() -> None:
    for line in code_lines():
        for token in ("??", "?.", " && ", " || "):
            assert token not in line, f"operator PowerShell 7 di: {line.strip()}"


def test_installers_do_not_use_start_process_wait() -> None:
    for line in code_lines():
        if "Start-Process" in line:
            assert "-Wait" not in line


def test_live_mode_is_forced_off() -> None:
    text = SCRIPT.read_text(encoding="ascii")
    assert "$answers['LIVE_ENABLED'] = 'false'" in text
    assert "if ($key -eq 'LIVE_ENABLED') { $value = 'false' }" in text
    assert not re.search(r"LIVE_ENABLED['\"]?\]?\s*=\s*['\"]?true", text, re.IGNORECASE)


def test_env_keys_written_by_script_exist_in_env_example() -> None:
    example_keys = set(re.findall(r"^([A-Z0-9_]+)=", ENV_EXAMPLE.read_text(), re.MULTILINE))
    script_keys = set(
        re.findall(r"\$answers\['([A-Z0-9_]+)'\]", SCRIPT.read_text(encoding="ascii"))
    )
    assert script_keys <= example_keys
    assert "LIVE_ENABLED=false" in ENV_EXAMPLE.read_text()
