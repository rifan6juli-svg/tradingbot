# TRD - TradingBot AI (MT5)

> Versi: 0.1 | Diperbarui: 2026-10-29 | Merujuk: PRD.md

## 1. Tech Stack
| Lapisan | Pilihan | Alasan (1 kalimat) |
|---|---|---|
| Bahasa/runtime | Python 3.11 (64-bit) | Paket `MetaTrader5` resmi hanya untuk Python di Windows. |
| Backend & loop bot | FastAPI + asyncio (satu proses) | Satu proses menjalankan loop trading dan API dashboard, tanpa orkestrasi tambahan. |
| Frontend | Jinja2 + HTML/CSS + JS polos (polling 5 detik) | Dashboard lokal sederhana, tanpa build step. |
| Database | SQLite (file `data/bot.db`) + SQLAlchemy 2.0 + Alembic | Satu pengguna, tanpa server DB, migrasi terversi. |
| Broker | MetaTrader 5 via paket `MetaTrader5` | Sesuai kebutuhan; diabstraksi lewat antarmuka `Broker`. |
| AI | SDK `anthropic` dan `openai` | Dua penyedia independen untuk konsensus. |
| Indikator | `pandas` + `ta` (atau perhitungan manual numpy) | Cukup untuk EMA/RSI/ATR/MACD. |
| HTTP klien | `httpx` | Ambil kalender ekonomi, timeout jelas. |
| Auth | Tidak ada login; bind `127.0.0.1` + header `X-Local-Token` untuk aksi tulis | Pengguna tunggal, lokal. |
| Hosting | PC Windows pemilik, jalan via `start.bat` | Terminal MT5 harus jalan di mesin yang sama. |

Versi runtime & package manager: Python 3.11, `pip` + `venv`, dependensi di `pyproject.toml`.

## 2. Arsitektur
Satu proses Python. **Orkestrator** menunggu candle M15 ditutup, lalu: ambil data (F-01) -> hitung fitur + cek berita (F-02) -> tanya semua AI paralel dan hitung konsensus (F-03) -> validasi risiko (F-04) -> eksekusi (F-05) -> simpan semua ke SQLite. Loop terpisah mengelola posisi (breakeven/trailing) dan rekonsiliasi tiap 10 detik. Dashboard (F-06, F-07) membaca SQLite dan memanggil modul lewat API FastAPI.

```mermaid
flowchart LR
  MT5[(MetaTrader 5)] <--> Broker[broker/ Broker interface]
  Broker --> Orch[Orkestrator]
  News[Feed kalender] --> Analysis[analysis/]
  Orch --> Analysis --> AI[ai/ Claude + OpenAI]
  AI --> Cons[Konsensus]
  Cons --> Risk[risk/ validasi + lot]
  Risk --> Exec[execution/]
  Exec --> Broker
  Orch --> DB[(SQLite)]
  Exec --> DB
  Web[web/ FastAPI + dashboard] --> DB
  Web --> Risk
```

Keputusan penting:
| Keputusan | Alternatif ditolak | Alasan |
|---|---|---|
| Antarmuka `Broker` + `MockBroker` | Panggil `MetaTrader5` langsung | MT5 hanya jalan di Windows; mock membuat tes jalan di mana pun. |
| AI hanya memberi arah + SL/TP; lot, batas, eksekusi dihitung kode | Biarkan AI menentukan lot | Risiko tidak boleh bergantung pada keluaran model. |
| Semua model wajib setuju | Mayoritas | Permintaan owner; lebih konservatif. |
| Strategi diskresi penuh AI | Setup berbasis aturan + AI sebagai penyaring | Keputusan owner; dikompensasi rem tambahan F-04. |
| Pelajaran terstruktur (kondisi + efek), efek diterapkan kode | Pelajaran teks bebas di prompt saja | Bisa diverifikasi kode dan dijamin hanya memperketat. |
| Penentang mingguan silang penyedia | Penentang per trade | Tanpa tambahan latensi/biaya per keputusan. |
| Panggil AI saat candle M15 tutup | Tiap tick/menit | Biaya API terkendali, cocok timeframe. |
| Satu proses | Worker terpisah (Celery dsb.) | Terlalu berat untuk pengguna tunggal. |
| SQLite | PostgreSQL | Tanpa server; data kecil. |

## 3. Struktur Folder
```
src/tradingbot/
  main.py              # entry: jalankan loop bot + web
  config.py            # baca .env + tabel settings
  db/                  # models.py, session.py, repo
  broker/              # base.py (Broker), mt5.py, mock.py
  analysis/            # indicators.py, features.py, news.py
  ai/                  # base.py (AIProvider + registry), claude.py, openai_provider.py, prompts.py, schema.py, consensus.py
  learning/            # reflection.py, lessons.py (usulan, verifikasi, efek), reviewer.py (penentang mingguan), versions.py (prompt_versions, rollback)
  risk/                # sizing.py, validator.py, guard.py (kill switch, limit)
  execution/           # executor.py, position_manager.py, reconcile.py
  journal/             # stats.py, summary.py
  web/                 # app.py, api.py, templates/, static/
migrations/            # Alembic
tests/
docs/
data/                  # bot.db (di-gitignore)
.env.example
start.bat
pyproject.toml
```

## 4. Konvensi Kode
- Bahasa & mode ketat: Python 3.11, type hints wajib di fungsi publik, `mypy` tidak diwajibkan; `from __future__ import annotations`.
- Penamaan: file/fungsi `snake_case`, kelas `PascalCase`, tabel `snake_case` jamak, enum nilai huruf kecil.
- Validasi input: Pydantic v2 untuk request API, keluaran AI (`ai/schema.py`), dan config.
- Penanganan error: exception khusus (`BrokerError`, `AIError`, `RiskBlocked`); error API format `{ "error": { "code", "message" } }`; error keputusan dicatat ke `risk_events`, bukan ditelan.
- Waktu: simpan UTC (`datetime` timezone-aware); konversi hanya di UI.
- Uang/harga: harga `float` dari broker apa adanya; hitung lot dengan `Decimal` atau pembulatan eksplisit ke `volume_step`.
- Lint/format: `ruff check .` dan `ruff format .`.
- Dilarang: API key di kode/log, SQL mentah tanpa parameter, memanggil `MetaTrader5` di luar `broker/mt5.py`, mengirim order tanpa SL/TP, menghapus penjaga risiko demi tes, mengubah `mode` ke live dari kode.

## 5. Keamanan
- Autentikasi: tidak ada login; server bind `127.0.0.1` saja. Semua request dengan header `Host` selain `127.0.0.1:8000`/`localhost:8000` ditolak 400 (anti DNS rebinding). Endpoint tulis (PUT/POST) wajib header `X-Local-Token` = `DASHBOARD_TOKEN` dari `.env`; server menyisipkan token ke halaman dashboard yang disajikannya (meta tag), JS membacanya dari sana. Tanpa CORS.
- Otorisasi: satu peran (owner); lihat BSD bagian 5.
- Penjaga mode live (semua harus benar, jika tidak bot menolak start):
  1. `LIVE_ENABLED=true` di `.env`
  2. `settings.mode = 'live'`
  3. Tipe akun MT5 = real (`account_info.trade_mode`) konsisten dengan mode
  4. Default dan fallback selalu `demo`; ketidakcocokan -> bot berhenti dan mencatat `risk_events.type = 'live_guard'`.
- Data sensitif: API key & token hanya di `.env` (di-gitignore); log disaring dari key.
- Sumber konfigurasi: tabel `settings` adalah sumber kebenaran runtime; nilai `.env` (`ANTHROPIC_MODEL` dan `OPENAI_MODEL` -> isi awal `ai_models`; `NEWS_PROVIDER`) hanya dipakai sebagai nilai awal saat seed. Secret (API key, token, `LIVE_ENABLED`) hanya di `.env`, tidak pernah di `settings`.
- Secrets: lewat environment variable, daftar di `.env.example`: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_MODEL` (contoh `claude-sonnet-5-5`), `OPENAI_MODEL` (wajib diisi owner), `NEWS_PROVIDER`, `MT5_PATH` (opsional), `DASHBOARD_TOKEN`, `LIVE_ENABLED`, `DB_PATH`.

## 5a. Aturan Broker MT5
- Akun wajib bertipe hedging (`account_info.margin_mode`); netting -> tolak start.
- Algo Trading terminal wajib aktif (`terminal_info.trade_allowed`); jika tidak -> tolak start dengan pesan.
- `type_filling` order dipilih dari `symbol_info.filling_mode` (FOK/IOC/RETURN), bukan dikodekan tetap.
- Setiap SL/TP baru (order maupun modifikasi) divalidasi terhadap `trade_stops_level` dan `trade_freeze_level`.
- Lot dihitung dengan `trade_tick_size`, `trade_tick_value_loss`, dan 2 x `commission_per_lot` (pulang-pergi), dibulatkan ke bawah ke `volume_step`.
- Buffer breakeven (jarak harga) = 2 x `commission_per_lot` x `trade_tick_size` / `trade_tick_value` + `breakeven_buffer_points` x `point`. Spread tidak dihitung (BUY: entry di ask, SL terpicu di bid; SELL sebaliknya).
- Hanya posisi dengan magic number bot yang dikelola/diambil alih; posisi lain diabaikan (akun khusus bot) tetapi ikut di equity.
- Sebelum entry, cek pasar simbol terbuka (`symbol_info.trade_mode` + sesi simbol); tutup -> `market_closed`.
- Reconnect: 10 detik x 5 kali, lalu tiap 60 detik tanpa batas; lanjut otomatis.

## 5b. Aturan AI
- Temperature tetap rendah (0-0.2) per penyedia; `prompt_version` (string, mis. `v1`) didefinisikan di `ai/prompts.py` dan disimpan di tiap `signals`.
- Penyedia didaftarkan di registry; `ai_opinions.provider` + `model` bebas (tanpa CHECK), sehingga penyedia atau model tambahan tidak butuh migrasi.
- Daftar model di `settings.ai_models` (JSON `[{provider, model, enabled}]`); konsensus memakai semua entri `enabled`.
- Prompt menyertakan batas `sl_atr_min`/`sl_atr_max`, `min_rr`, dan aturan sisi SL/TP; skema menolak SL/TP di sisi salah.
- Ringkasan jurnal (F-07) memakai model aktif pertama di `ai_models`.
- Total model aktif <= `max_ai_models`; panggilan paralel sehingga latensi = model paling lambat (timeout 30 detik).
- Pelajaran (F-08) terstruktur: `condition_json` atas kunci fitur di `features_json` (operator `>`, `<`, `>=`, `<=`, `==`, digabung AND), `symbol`/`direction` opsional, efek `avoid` atau `raise_confidence`. Kode mengevaluasi kondisi dan menerapkan efek pada opini model pemilik sebelum konsensus; teks pelajaran juga disisipkan ke prompt model pemilik.
- Penentang: model aktif pertama dari penyedia lain (jika tidak ada model aktif dari penyedia lain, pelajaran pending tidak diaktifkan); satu panggilan per model pemilik per minggu; keluaran terstruktur (`lesson_id`, `verdict` keep/reject, alasan).
- Job mingguan dijalankan orkestrator pada `lesson_review_utc`; idempotensi per minggu (`prompt_versions.week_start`).

## 6. Environment & Deploy
| Env | Tujuan | Catatan |
|---|---|---|
| dev/CI (Linux/Windows) | Tes unit dengan `MockBroker` dan AI palsu | Tanpa MT5, tanpa API key. |
| windows-demo | Jalan nyata di akun demo | MT5 terbuka dan login ke akun demo; `start.bat`. |
| windows-live | Ditunda | Hanya setelah kriteria PRD bagian 3 terpenuhi dan disetujui owner. |

Variabel lingkungan: lihat `.env.example`.
CI/CD: tidak ada untuk MVP; `ruff` dan `pytest` dijalankan lokal.

## 7. Strategi Testing
- Unit: `pytest` untuk indikator, sizing lot, validator SL/TP, konsensus, penjaga risiko, kill switch, parser keluaran AI (termasuk JSON rusak), evaluator kondisi dan efek pelajaran, rollback versi prompt.
- Integrasi: alur lengkap dengan `MockBroker` + AI palsu (siklus candle -> sinyal -> order -> sinkron).
- Manual di Windows (langkah IPD yang menyentuh MT5): checklist terhadap akun demo.
- Perintah standar: `pytest`, `ruff check .`, `python -m tradingbot` (jalankan), tidak ada build.

## 8. Non-Fungsional Teknis
- Performa: panggilan AI paralel (`asyncio.gather`), timeout 30 detik per model; total siklus <= 60 detik.
- Skala awal: 2 simbol x 2 timeframe; < 1 MB data/hari di SQLite.
- Observability: log berputar ke `logs/bot.log` (level INFO), semua penolakan/error di `risk_events`; endpoint `/api/status` menyertakan `last_cycle_at`.
- Idempotensi: `signals` unik per (`symbol`, `timeframe`, `bar_time`) agar candle yang sama tidak diproses dua kali setelah restart.

## 9. Risiko Teknis
- `MetaTrader5` hanya Windows -> abstraksi `Broker` + mock; langkah MT5 diuji manual.
- Feed kalender gratis (tidak resmi) berubah/mati -> fail-safe blokir entry + log; `NewsProvider` dapat diganti di `analysis/news.py`; jendela blokir manual sebagai cadangan.
- Perbedaan nama simbol antarbroker -> `symbol_map` + auto-deteksi kandidat dari `symbols_get` MT5.
- Biaya/latensi API AI -> panggilan hanya saat candle tutup, timeout, hitung biaya di log.
- Keluaran AI tidak valid -> skema Pydantic ketat; gagal = tidak setuju.
- Jam/zona waktu server broker berbeda dari UTC -> semua waktu dinormalisasi ke UTC di `broker/mt5.py`.
