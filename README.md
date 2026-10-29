# TradingBot AI (MT5)

Bot trading otomatis untuk MetaTrader 5 (XAUUSD, EURUSD) di Windows. Beberapa model AI (Claude + OpenAI) menganalisa pasar, dan order hanya dieksekusi jika semua model setuju serta lolos batas risiko. Tahap awal: **akun demo saja**.

Status: dalam pengembangan. Progres ada di `docs/IPD.md`.

## Setup VPS Windows baru

Butuh VPS **Windows** (Windows Server 2022/2025 atau Windows 10/11, 64-bit), karena paket `MetaTrader5` hanya tersedia untuk Windows. Spesifikasi minimal yang disarankan: 2 vCPU, 4 GB RAM, 40 GB disk.

1. Masuk ke VPS lewat RDP dengan akun yang akan menjalankan bot.
2. Buka **PowerShell sebagai Administrator**, lalu jalankan:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   Invoke-WebRequest https://raw.githubusercontent.com/rifan6juli-svg/tradingbot/main/scripts/setup_vps.ps1 -OutFile "$env:TEMP\setup_vps.ps1" -UseBasicParsing
   & "$env:TEMP\setup_vps.ps1"
   ```

3. Isi pertanyaan yang muncul (API key, model OpenAI, login akun demo MT5, Telegram opsional). Input secret tidak ditampilkan.
4. Baca ringkasan di akhir, lalu kerjakan langkah manual yang ditampilkan (cek Algo Trading di MT5; keluar dari RDP dengan **Disconnect**, bukan Sign out).

Skrip memasang Python 3.14, Git, dan MetaTrader 5, menyiapkan bot di `C:\tradingbot`, membuat `.env`, mengatur Windows agar tidak sleep, dan mendaftarkan MT5 + bot di Task Scheduler. Untuk update bot, jalankan ulang skrip yang sama. Jika repo sudah privat, salin skrip ke VPS lalu jalankan dengan `-PrivateRepo`. Detail parameter: `docs/TRD.md` bagian 6a.

## Pengembangan

```bash
python3.14 -m venv .venv
.venv/bin/pip install -e ".[dev]"
.venv/bin/ruff check . && .venv/bin/pytest
```

Di Linux, `MetaTrader5` tidak ikut terpasang; tes memakai `MockBroker`.

## Dokumen proyek

| Dokumen | Isi |
|---|---|
| `docs/PRD.md` | Fitur (F-xx), scope, kriteria penerimaan |
| `docs/TRD.md` | Stack, arsitektur, konvensi kode, setup VPS |
| `docs/AFD.md` | Layar (S-xx) dan alur |
| `docs/DBD.md` | Panduan desain dashboard |
| `docs/BSD.md` | Skema database dan API |
| `docs/IPD.md` | Rencana kerja bertahap dan status |

Dokumen dikelola dengan skill `vibe-docs` (`/vibe-docs build`, `/vibe-docs update`, `/vibe-docs check`).
