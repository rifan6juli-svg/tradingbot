# IPD - TradingBot AI (MT5)

> Versi: 0.5 | Diperbarui: 2026-10-29 | Merujuk: PRD, TRD, AFD, DBD, BSD

## Cara memakai
Kerjakan **satu langkah per sesi**, berurutan. Centang `[x]` hanya jika kriteria "Selesai jika" terbukti lolos. Jangan mengerjakan fitur di luar langkah yang aktif.
Langkah bertanda **[Windows]** harus diuji manual di PC/VPS Windows dengan MT5 akun demo khusus bot; di lingkungan lain, cukup lewat `MockBroker`.
**Semua pengujian dengan uang nyata dilarang** sampai kriteria PRD bagian 3 terpenuhi dan owner menyetujui eksplisit.

## Ringkasan Fase
| Fase | Tujuan | Langkah | Estimasi |
|---|---|---|---|
| 1 | Fondasi | 1-5b | ~19 jam (2 minggu) |
| 2 | Alur inti (analisa, AI, risiko, eksekusi) | 6-15 | ~43 jam (4.5 minggu) |
| 3 | Dashboard, jurnal & pelajaran AI | 16-21e | ~36 jam (3.5 minggu) |
| 4 | Notifikasi, polesan, hardening, uji demo | 22-26 | ~17 jam + >= 4 minggu uji demo berjalan |

Total 42 langkah, ~115 jam pengerjaan (~11-12 minggu pada ~10 jam/minggu), lalu >= 4 minggu uji demo.

## Fase 1 - Fondasi

- [ ] **1. Setup proyek**
  - Rujukan: TRD bagian 1, 3, 4
  - Kerjakan: `pyproject.toml` (dependensi dipin, `MetaTrader5` dengan penanda `sys_platform == "win32"`, extra `dev`: pytest, ruff), struktur folder `src/tradingbot/...` sesuai TRD 3, `.env.example` (semua variabel TRD 5), `.gitignore` (`.env`, `data/`, `logs/`), `start.bat` awal, `python -m tradingbot --version`
  - Selesai jika: `pip install -e .[dev]` berhasil di Linux (tanpa `MetaTrader5`) dan di Windows; `ruff check .` dan `pytest` (satu tes dummy) lolos

- [ ] **2. Database & skema**
  - Rujukan: BSD bagian 2-4, 7
  - Kerjakan: model SQLAlchemy + migrasi Alembic untuk semua tabel BSD (termasuk indeks parsial), SQLite mode WAL, seed `settings` default (termasuk `ai_models` dari `.env`) dan `prompt_versions` `v1`, helper sesi
  - Selesai jika: migrasi berjalan dari nol; seed terisi dan tercatat di `settings_changes` (`source = seed`); tes skema (CHECK, UNIQUE, indeks parsial `ai_lessons`/`paper_outcomes`) lolos

- [ ] **3. Config, Clock & penjaga mode**
  - Rujukan: TRD bagian 4, 5, F-05 (kriteria mode live), BSD `settings` (aturan validasi lintas key), `settings_changes`
  - Kerjakan: antarmuka `Clock` + `FakeClock`; loader `.env` + `settings` dengan validasi batas per key dan lintas key (Pydantic); semua penulisan setting lewat satu fungsi yang mencatat `settings_changes`; `check_live_guard(account_type)`, default paksa `demo`
  - Selesai jika: tes membuktikan: mode `live` ditolak tanpa `LIVE_ENABLED=true`; ditolak jika tipe akun tidak cocok; nilai di luar batas ditolak; setiap aturan lintas key di BSD ditolak saat dilanggar; setiap perubahan tercatat dengan nilai lama, nilai baru, dan sumbernya

- [ ] **4. Broker interface & MockBroker**
  - Rujukan: F-01, TRD bagian 2-3, 5a, 7
  - Kerjakan: `Broker` (info akun, candle, tick/spread, info simbol termasuk `tick_size`/`tick_value_loss`/`stops_level`/`freeze_level`/status pasar, `order_check`, kirim order, posisi terbuka, modifikasi SL/TP, tutup posisi, riwayat deal termasuk deposit/penarikan) + `MockBroker` yang mensimulasikan spread, `stops_level`, `freeze_level`, slippage, partial fill, margin, hasil `order_send` yang hilang, dan putus koneksi
  - Selesai jika: tes unit MockBroker lolos (order dengan SL/TP, tutup, riwayat, posisi tanpa magic, penolakan karena margin, `stops_level`)

- [ ] **5a. MT5Broker: thread pekerja, koneksi & data [Windows]**
  - Rujukan: F-01, TRD bagian 5a, 9
  - Kerjakan: `broker/worker.py` (satu thread pekerja, antrean, pemanggil async), implementasi `Broker` di `broker/mt5.py` lewat pekerja, normalisasi waktu ke UTC, pemetaan simbol via `symbol_map` + pencarian kandidat (`symbols_get`), ambil >= 2000 candle M15 dan >= 1000 H1, skrip `scripts/check_mt5.py` yang mencetak akun/tipe/margin mode/filling/candle
  - Selesai jika: tes: panggilan bersamaan dari beberapa coroutine diproses berurutan oleh pekerja (dengan broker palsu); di Windows, skrip mencetak saldo, tipe akun DEMO, dan jumlah candle yang diminta untuk kedua simbol kanonik lewat nama broker; kontrak tes `Broker` yang sama lolos untuk Mock dan MT5

- [ ] **5b. MT5Broker: cek start, reconnect, batas broker [Windows]**
  - Rujukan: F-01, TRD bagian 5a
  - Kerjakan: cek saat start (Algo Trading aktif, akun hedging, `filling_mode`), status pasar simbol, abaikan posisi tanpa magic bot, reconnect (10 detik x 5, lalu tiap 60 detik tanpa batas, lanjut otomatis), helper validasi `stops_level`/`freeze_level`, `order_check`, riwayat deal
  - Selesai jika: Algo Trading dimatikan -> start ditolak dengan pesan; mematikan MT5 memicu status terputus, menyalakan kembali setelah > 1 menit membuat bot lanjut sendiri; posisi manual di terminal tidak diambil alih; `order_check` mengembalikan info margin di akun demo; tes helper `stops_level` lolos

## Fase 2 - Alur Inti

- [ ] **6. Fitur skema `f1`**
  - Rujukan: F-02, TRD bagian 5c, BSD `signals.features_json`/`feature_schema`
  - Kerjakan: EMA, RSI dan ATR (Wilder), MACD, swing fractal 5-bar, fitur skalar ternormalisasi dan konteks sesuai TRD 5c; `build_features(candles_m15, candles_h1, tick, news)` hanya dari candle tutup
  - Selesai jika: tes nilai acuan pada data tetap (toleransi 1e-6); tes tanpa lookahead (candle yang sedang berjalan tidak memengaruhi hasil); semua kunci `f1` ada dengan nama persis; data di bawah batas minimum ditolak dengan pesan jelas

- [ ] **7. Filter berita**
  - Rujukan: F-02, BSD `news_events`, `settings.news_block_minutes`, `settings.manual_blackouts`
  - Kerjakan: `analysis/news.py` dengan `NewsProvider` yang dapat diganti (default feed Forex Factory mingguan), httpx + timeout, simpan upsert, dukung `manual_blackouts`, `is_news_blocked(symbol, now)`, cek cakupan kalender, pemetaan simbol -> mata uang (XAUUSD: USD; EURUSD: EUR, USD). Verifikasi feed nyata dari PC Windows.
  - Selesai jika: tes: dalam `± news_block_minutes` event high -> `news_block`; di luar -> lolos; manual blackout -> blokir; data > 24 jam / fetch gagal / kalender tidak mencakup waktu sekarang -> `calendar_stale` dan `risk_events` hanya sekali saat kondisi mulai

- [ ] **8. Antarmuka AI, adapter Claude & pencatatan panggilan**
  - Rujukan: F-03, TRD bagian 1, 4, 5b, BSD `ai_calls`
  - Kerjakan: `ai/schema.py` (Pydantic: direction, confidence, sl_price, tp_price, rationale; SL/TP wajib untuk buy/sell, boleh kosong untuk hold; SL/TP sisi salah -> tidak valid), `ai/prompts.py` (dengan `prompt_version`, paket `f1`, batas ATR/RR, aturan sisi, slot teks pelajaran), `AIProvider` base + registry, `claude.py` (output terstruktur, timeout 30 detik, temperature rendah tetap, model dari `ai_models`), `ai/calls.py` (catat `ai_calls`: token, biaya dari `ai_price_table`, latensi, `error_kind`)
  - Selesai jika: tes dengan klien palsu: balasan valid di-parse; JSON rusak / timeout / SL di sisi salah menghasilkan `AIError` terkontrol dan baris `ai_calls` dengan `error_kind` yang benar; 1 panggilan nyata manual ke Claude mengembalikan opini valid dan mencatat token

- [ ] **9. Adapter OpenAI**
  - Rujukan: F-03, TRD bagian 5b
  - Kerjakan: `ai/openai_provider.py` dengan skema, prompt, timeout, dan pencatatan yang sama; model dari `ai_models` (bukan langsung dari `.env`)
  - Selesai jika: tes klien palsu setara langkah 8 lolos; 1 panggilan nyata manual valid

- [ ] **10a. Konsensus & penyimpanan sinyal**
  - Rujukan: F-03, BSD `signals`, `ai_opinions`
  - Kerjakan: panggilan paralel (`asyncio.gather`) ke semua model `enabled`, `consensus.py` (semua model aktif sama arah, bukan hold, conf >= `min_confidence`, jumlah >= `min_ai_models`, diversitas penyedia bila wajib; kurang -> `blocked` `insufficient_ai_models` tanpa memanggil AI), simpan `signals` (simbol kanonik, `feature_schema`, `prompt_version`, bid/ask, `raw_consensus` = `consensus` sampai langkah 21c) + `ai_opinions` (`raw_direction` = `direction` sampai 21c), idempotensi per (`symbol`,`timeframe`,`bar_time`)
  - Selesai jika: tes tabel kebenaran (setuju / beda arah / satu hold / satu error / SL sisi salah / satu nonaktif / dua model satu penyedia / tanpa model OpenAI saat diversitas wajib) lolos; sinyal yang sama tidak tersimpan dua kali

- [ ] **10b. Kesehatan & anggaran AI**
  - Rujukan: F-03, TRD bagian 5b, BSD `ai_calls`
  - Kerjakan: hitung error beruntun per model dari `ai_calls`; tidak sehat -> `blocked` `ai_unhealthy` tanpa memanggil model lain, uji ulang (`probe`) tiap 4 candle, pulih setelah satu sukses; `risk_events` saat mulai/pulih; cek `max_ai_calls_per_day` sebelum memanggil -> `ai_budget` sampai 00:00 UTC
  - Selesai jika: tes jam palsu: 3 error beruntun -> tidak sehat; error `auth`/`model_not_found` -> langsung tidak sehat; probe sukses -> pulih; batas panggilan tercapai -> `ai_budget` lalu lolos setelah 00:00 UTC

- [ ] **11a. Validasi SL/TP & guard entry**
  - Rujukan: F-04, BSD `settings`, enum `block_reason`
  - Kerjakan: gabung SL terjauh + TP terdekat, validasi jarak SL (`sl_atr_min`-`sl_atr_max`) dan RR (`min_rr`), guard spread (`max_spread_atr_ratio` x ATR M15), sesi, pasar tutup, maks posisi; blokir rutin hanya di `signals.block_reason`
  - Selesai jika: tes: SL di luar batas ATR -> `invalid_sltp`; RR < `min_rr` -> `invalid_sltp`; spread > batas -> `spread_too_wide`; di luar sesi -> `outside_session`; pasar tutup -> `market_closed`; posisi penuh -> `max_positions`; tidak ada baris `risk_events` untuk blokir rutin

- [ ] **11b. Lot, margin & validasi ulang**
  - Rujukan: F-04, TRD bagian 5a
  - Kerjakan: lot dengan rumus PRD F-04 (`tick_size`, `tick_value_loss`, 2 x `commission_per_lot`, bulat ke bawah ke `volume_step`, batas `volume_max`), `order_check` + margin level >= `min_margin_level_pct`, `deviation` dari `max_slippage_atr_ratio`, fungsi validasi ulang (spread, SL/TP, lot, margin) dengan bid/ask terbaru
  - Selesai jika: tes: lot benar untuk XAUUSD dan EURUSD (contoh tetap, termasuk kontrak 100 oz) dan risiko rencana tidak pernah > target; lot < `volume_min` -> `lot_too_small`; margin kurang -> `insufficient_margin`; harga terbaru melewati SL -> `invalid_sltp`; spread melebar saat validasi ulang -> `spread_too_wide`

- [ ] **11c. Rem tambahan (tahan restart)**
  - Rujukan: F-04 (rem tambahan, tahan restart), TRD bagian 5a, BSD `settings`, `daily_stats`, `trades`
  - Kerjakan: kalah beruntun + jeda (dari `trades`), maks entry terisi per hari (dari `trades`), rugi mingguan (baseline Senin dari riwayat deal), lonjakan volatilitas (ATR M15 vs median 20 hari bursa), cutoff Jumat; `risk_events` saat jeda/blokir mulai
  - Selesai jika: tes jam palsu: 3 kalah beruntun -> `consecutive_losses` selama 4 jam lalu lolos; trade profit >= 0 me-reset hitungan; entry ke-5 dalam sehari -> `max_entries_day`; rugi mingguan 4% -> `weekly_loss_limit` sampai Senin; ATR 3.5x median -> `volatility_shock`; Jumat 18:01 UTC -> `friday_cutoff`, Senin saat pasar buka -> lolos; restart (state dibangun ulang dari DB + riwayat deal palsu) tidak me-reset rem; deposit tidak dihitung sebagai profit

- [ ] **12a. Batas rugi harian & kill switch dasar**
  - Rujukan: F-04, BSD `daily_stats`, `risk_events`, `settings.kill_switch*`
  - Kerjakan: `daily_stats.start_balance` dari riwayat deal, rugi harian = (`start_balance` - equity) / `start_balance`, pemicu otomatis, `trigger_kill_switch(reason, mode)` untuk mode `close_all`, fungsi panic (selalu tutup semua), reset manual dan reset otomatis hari berikutnya (hanya untuk pemicu batas harian)
  - Selesai jika: tes MockBroker: rugi mencapai `max_daily_loss_pct` -> kill switch ON, semua posisi bot tertutup (`close_all`), entry berikutnya diblokir (`kill_switch`), `risk_events` tercatat; restart di tengah hari tetap memakai baseline yang sama; reset manual dan otomatis berfungsi; kill switch manual tidak ter-reset otomatis

- [ ] **12b. Mode `protect_winners`**
  - Rujukan: F-04, F-05 (buffer breakeven), TRD bagian 5a
  - Kerjakan: di `trigger_kill_switch`: tutup posisi rugi; posisi untung -> SL ke minimal breakeven + buffer; jika SL itu tidak bisa dipasang valid (`stops_level`/`freeze_level`/sisi harga) -> tutup (`sltp_unplaceable`)
  - Selesai jika: tes MockBroker: posisi rugi tertutup; posisi untung tetap hidup dengan SL >= breakeven + buffer; posisi untung tipis yang SL-nya tidak valid ikut ditutup; posisi tanpa magic bot tidak disentuh

- [ ] **13a. Eksekusi order: kunci, idempotensi, risiko aktual**
  - Rujukan: F-04 (kunci eksekusi), F-05, TRD bagian 5a, BSD `trades`
  - Kerjakan: `executor.py`: kunci eksekusi (satu order pada satu waktu) dengan cek ulang semua guard/rem dan validasi 11b di dalamnya; order market + SL/TP + magic + comment `tb:<signal_id>` + `deviation` + `type_filling` dari broker; hasil gagal/tidak pasti -> cari posisi/deal (magic + simbol + waktu + comment) -> ambil alih atau validasi ulang lalu 1 retry -> `rejected`; setelah fill hitung `risk_amount` dari harga fill, > 110% `planned_risk_amount` -> `excess_risk`
  - Selesai jika: tes MockBroker: dua simbol lolos bersamaan dengan `max_open_positions` = 1 -> hanya satu order terkirim; respons `order_send` hilang tetapi posisi terisi -> tidak ada order kedua; ditolak -> validasi ulang lalu `rejected` tanpa retry kedua; slippage besar -> `excess_risk` tercatat

- [ ] **13b. Rekonsiliasi**
  - Rujukan: F-05, BSD `trades` (aturan `close_reason`)
  - Kerjakan: `reconcile.py`: sinkron `trades` dengan posisi/deal broker berdasarkan magic; ambil alih posisi ber-magic saat start (`risk_amount` dari SL); isi `broker_symbol`; `close_reason` sesuai aturan BSD; rugi > 110% `risk_amount` -> `excess_loss`
  - Selesai jika: tes MockBroker: restart mengambil alih posisi ber-magic saja; posisi tertutup di broker -> `closed` dengan profit dan `close_reason` benar untuk tp/sl/breakeven/trailing/manual; gap melewati SL -> `excess_loss` tercatat

- [ ] **14. Breakeven & trailing**
  - Rujukan: F-05, TRD bagian 5a
  - Kerjakan: `position_manager.py` (+1R -> SL ke breakeven + buffer, dengan buffer = komisi pulang-pergi dikonversi ke jarak harga + `breakeven_buffer_points`, tanpa spread; +1.5R -> trailing 1 x ATR; SL hanya bergerak searah menguntungkan; modifikasi hanya jika perbaikan >= `trailing_min_step_atr` x ATR; cek `stops_level`/`freeze_level` sebelum modifikasi)
  - Selesai jika: tes simulasi harga menunjukkan SL bergeser tepat pada ambang, berada di atas entry (BUY) / di bawah entry (SELL) sebesar buffer, tidak pernah mundur, perbaikan < `trailing_min_step_atr` x ATR tidak memicu modifikasi, dan keluar di level breakeven menghasilkan profit bersih >= 0 setelah komisi

- [ ] **15. Orkestrator end-to-end (demo) [Windows]**
  - Rujukan: seluruh F-01 s.d. F-05, AFD bagian 3, TRD bagian 2, 5a
  - Kerjakan: `main.py`: kunci satu instans (`data/bot.lock`), loop menunggu candle M15 tutup per simbol, seluruh pipeline, loop posisi 10 detik dengan heartbeat (`data/heartbeat`), logging ke `logs/bot.log`
  - Selesai jika: tes integrasi MockBroker + AI palsu menjalankan siklus penuh (buy, sell, skip, blocked); instans kedua menolak start; di Windows akun demo, bot berjalan >= 2 jam, setiap candle menghasilkan `signals`, tidak ada order tanpa SL/TP, semua keputusan tercatat

## Fase 3 - Dashboard, Jurnal & Pelajaran AI

- [ ] **16. Web skeleton & S-01 Dashboard**
  - Rujukan: F-03, F-06, AFD S-01, DBD bagian 1-3, BSD `/api/status`, `/api/risk-events`
  - Kerjakan: FastAPI bind 127.0.0.1 pada `DASHBOARD_PORT`, middleware cek header `Host`, sisipkan `DASHBOARD_TOKEN` ke meta tag halaman, template dasar (header, navigasi, badge mode, tombol kill switch), `/api/status` lengkap, S-01 dengan polling 5 detik: kartu status, panel "Kenapa bot tidak trading" (`active_blocks`), kesehatan AI, panggilan/biaya AI hari ini, daftar `risk_events`, banner (tidak terjangkau, heartbeat usang, tidak ada entry `starvation_days` hari); waktu lokal browser + UTC di tooltip
  - Selesai jika: S-01 menampilkan status nyata dari MockBroker; blokir aktif tampil dengan waktu berakhir; mematikan backend memunculkan banner; heartbeat usang memunculkan banner; tes API status lolos; request dengan `Host: evil.com` -> 400

- [ ] **17. S-02 Sinyal & Opini AI**
  - Rujukan: F-03, F-06, AFD S-02, BSD `/api/signals`
  - Selesai jika: tabel sinyal dengan baris yang bisa diperluas memperlihatkan opini + alasan tiap model, arah asli vs final, dan `block_reason`; filter simbol berfungsi

- [ ] **18. S-03 Posisi & Riwayat**
  - Rujukan: F-05, F-06, AFD S-03, BSD `/api/trades`
  - Selesai jika: tab Terbuka/Riwayat benar; tautan ke sinyal asal berfungsi; profit berwarna + teks tanda; `excess_loss`/`excess_risk` diberi tanda

- [ ] **19a. S-04 Pengaturan**
  - Rujukan: F-03, F-04, F-06, F-08, AFD S-04, DBD S-04, BSD `settings`, `/api/settings`, `/api/settings/changes`, `/api/symbols/candidates`
  - Kerjakan: form pengaturan risiko dan rem, pilih `symbol_map` dari kandidat MT5, pilih `kill_switch_mode`, editor `ai_models` (beberapa model per penyedia, tambah/aktif/nonaktif), `ai_price_table`, toggle `lessons_enabled`/`lessons_frozen`, input `breakeven_buffer_points` dan `commission_per_lot`, tabel riwayat perubahan
  - Selesai jika: ubah risiko tersimpan, tercatat di riwayat, dan berlaku siklus berikutnya; nilai di luar batas atau melanggar aturan lintas key ditolak dengan pesan; ubah `symbol_map` saat ada posisi terbuka -> 409; tanpa token -> 401

- [ ] **19b. S-04 Kontrol kill switch**
  - Rujukan: F-04, F-06, AFD S-04, BSD `/api/kill-switch`, TRD bagian 5
  - Kerjakan: tombol kill switch, reset, dan "Tutup semua sekarang" dengan dialog konfirmasi
  - Selesai jika: kill switch, reset, dan panic bekerja dengan dialog konfirmasi; coba ubah `mode`/`kill_switch` lewat PUT -> 403

- [ ] **20. Statistik jurnal & kelayakan live**
  - Rujukan: F-07, PRD bagian 3 (definisi), BSD `daily_stats`, `journal_entries`, `settings_changes`
  - Kerjakan: `journal/stats.py` (jumlah trade, win rate, profit factor, rata-rata R, net profit, max drawdown sesuai definisi PRD), simpan harian/mingguan, `live_readiness()` terhadap kriteria PRD bagian 3 (hanya trade `account_mode = demo`; `prompt_version` terakhir stabil >= 2 minggu; rata-rata R versi itu >= 0; tidak ada perubahan pengaturan risiko 2 minggu terakhir)
  - Selesai jika: tes dengan set trade tetap menghasilkan angka acuan; `live_readiness` benar untuk kasus lolos dan setiap kasus gagal; `excess_loss` akibat gap tidak dihitung sebagai pelanggaran

- [ ] **20a. Hasil hipotetis**
  - Rujukan: F-08, TRD bagian 5b, BSD `paper_outcomes`
  - Kerjakan: `learning/paper.py`: buat `pending` untuk setiap opini buy/sell (arah dan SL/TP asli) dan setiap sinyal yang dibatalkan pelajaran; selesaikan tiap candle M15 tutup memakai candle berikutnya; aturan sisi bid/ask, SL dan TP di candle sama -> SL, `timeout` setelah `paper_horizon_candles`
  - Selesai jika: tes data tetap: TP lebih dulu -> `tp` dengan R benar; SL lebih dulu -> `sl` (R = -1); keduanya di candle sama -> `sl`; tidak tersentuh -> `timeout` dengan R dari close terakhir; sell memperhitungkan spread; tidak ada hasil ganda per opini

- [ ] **20b. Scorecard model & kalibrasi**
  - Rujukan: F-07, BSD `/api/scorecard`
  - Kerjakan: `journal/scorecard.py`: per model jumlah sampel, win rate, rata-rata R, kalibrasi confidence (0.6-0.7, 0.7-0.8, 0.8-0.9, 0.9-1.0) dari `paper_outcomes` jenis `opinion`; `GET /api/scorecard`
  - Selesai jika: tes pada data tetap menghasilkan angka acuan; filter model dan `since` berfungsi

- [ ] **21. Ringkasan AI & S-05 Jurnal**
  - Rujukan: F-07, AFD S-05, BSD `/api/journal`, TRD bagian 5b
  - Kerjakan: ringkasan memakai model aktif pertama di `ai_models` (input hanya statistik); S-05 menampilkan statistik, ringkasan, progres kelayakan live, dan scorecard + kalibrasi
  - Selesai jika: ringkasan tersimpan dan tampil; AI gagal -> statistik tetap tampil dengan tombol coba lagi; S-05 menampilkan progres kriteria live dan scorecard

- [ ] **21a. Refleksi pasca-trade**
  - Rujukan: F-08, BSD `ai_reflections`, TRD 5b
  - Kerjakan: `learning/reflection.py`: saat trade `closed` dan punya sinyal asal, minta tiap model yang ikut memutuskan menulis refleksi + usulan opsional dalam satu panggilan; simpan; gagal -> `error` terisi; anggaran AI tercapai -> ditunda
  - Selesai jika: tes AI palsu: trade tertutup menghasilkan satu refleksi per model; posisi yang diambil alih tanpa sinyal tidak direfleksikan; error tidak menghentikan rekonsiliasi; tidak ada refleksi ganda

- [ ] **21b. Usulan pelajaran & verifikasi kode**
  - Rujukan: F-08, TRD bagian 5b, 5c, BSD `ai_lessons`
  - Kerjakan: skema usulan terstruktur; validator (kunci skalar `f1`, hanya memperketat, `effect_value` > `min_confidence`); `lesson_key` (gabung duplikat, `support_count`); cooldown `lesson_cooldown_weeks`; bukti dari `paper_outcomes` opini model pemilik; status `pending` bila >= `lesson_min_samples`, rata-rata R < 0, dan lebih buruk dari rata-rata model; teks pelajaran dari template
  - Selesai jika: tes: usulan melonggarkan ditolak; kunci tidak dikenal ditolak; usulan identik digabung; usulan dalam cooldown ditolak; bukti dihitung benar pada data tetap; < 20 sampel tidak menjadi pending; teks pelajaran tidak memuat kata dari keluaran AI

- [ ] **21c. Penerapan pelajaran & versi prompt**
  - Rujukan: F-03, F-08, BSD `prompt_versions`, `signals.raw_consensus`, `ai_opinions.raw_direction`/`lessons_applied`
  - Kerjakan: evaluator kondisi, efek `avoid`/`raise_confidence` pada opini model pemilik sebelum konsensus, teks template pelajaran di prompt model pemilik, `raw_consensus` vs `consensus`, buat `paper_outcomes` jenis `lesson_veto`, `prompt_versions` aktif, `lessons_enabled` = 0 -> prompt dasar
  - Selesai jika: tes: kondisi cocok -> opini model pemilik jadi hold (`avoid`) atau tidak setuju bila confidence < nilai (`raise_confidence`); model lain tidak terpengaruh; `raw_direction`, `lessons_applied`, `raw_consensus` tercatat; sinyal yang dibatalkan mendapat hasil hipotetis `lesson_veto`; mematikan pelajaran langsung kembali ke prompt dasar

- [ ] **21d. Job mingguan: verifikasi ulang, rollback, penentang, aktivasi**
  - Rujukan: F-08, TRD bagian 5b (urutan job mingguan)
  - Kerjakan: `learning/weekly.py` pada `lesson_review_utc` (idempotensi per minggu): selesaikan hasil hipotetis, verifikasi ulang + kedaluwarsa, rollback (rata-rata R trade nyata vs versi sebelumnya, aktifkan kembali baris lama), penentang silang penyedia, aktivasi dengan batas per model dan total, versi baru berlaku Senin, `lessons_frozen` hanya mencatat, anggaran AI tercapai -> penentang ditunda
  - Selesai jika: tes jam palsu: pelajaran yang buktinya hilang -> `expired`; rollback mengaktifkan kembali baris sebelumnya tanpa baris baru dan melewati aktivasi minggu itu; penentang `reject` -> pending `rejected` / aktif `disabled`; penentang error -> tidak ada perubahan; batas `lesson_max_active_total` dihormati; versi baru paling banyak sekali per minggu; frozen -> status tidak berubah

- [ ] **21e. UI pelajaran (S-05) & pengaturan (S-04)**
  - Rujukan: F-08, AFD S-04/S-05, DBD S-04/S-05, BSD `/api/lessons`, `/api/prompt-versions`
  - Selesai jika: S-05 menampilkan pelajaran per model dengan status, kondisi, efek, bukti, catatan penentang, jumlah sinyal yang dibatalkan dan hasil hipotetisnya; riwayat versi prompt tampil; toggle di S-04 berlaku pada siklus berikutnya

## Fase 4 - Notifikasi, Polesan, Hardening & Uji Demo

- [ ] **22. State kosong/loading/error semua layar**
  - Rujukan: AFD bagian 5, DBD bagian 3
  - Selesai jika: tiap layar S-01 s.d. S-05 menampilkan keempat state sesuai tabel AFD (diverifikasi manual + tes render)

- [ ] **23. Aksesibilitas & responsivitas**
  - Rujukan: DBD bagian 4-5
  - Selesai jika: navigasi dan aksi bisa lewat keyboard; kontras >= 4.5:1; tampilan tidak pecah pada lebar 360px; arah buy/sell punya teks

- [ ] **23a. Notifikasi Telegram**
  - Rujukan: F-09, TRD bagian 5, BSD `notifications`, `/api/notifications/test`
  - Kerjakan: `notify/telegram.py` (httpx, retry 3x), `notify/events.py` (jenis kejadian, cooldown per jenis), sambungkan semua kejadian di PRD F-09, deteksi tidak ada entry selama `starvation_days`, tombol "Kirim tes" di S-04, status notifikasi di `/api/status`
  - Selesai jika: tes: kejadian yang sama dalam cooldown -> `suppressed`; Telegram gagal -> 3 percobaan lalu `failed` tanpa menghambat siklus trading; token kosong -> `disabled`; pesan tidak memuat secret atau saldo nominal; manual: pesan tes sampai di HP owner

- [ ] **23b. Watchdog & heartbeat**
  - Rujukan: F-09, TRD bagian 2, 5a, 6
  - Kerjakan: `watchdog.py`: jalankan proses bot, jalankan ulang jika keluar atau heartbeat > 2 menit (maks 5 kali per jam, lalu berhenti), notifikasi `bot_started`/`bot_restarted`/`bot_down`; `start.bat` menjalankan watchdog
  - Selesai jika: tes dengan proses palsu: proses keluar -> dijalankan ulang; heartbeat usang -> dihentikan dan dijalankan ulang; > 5 restart per jam -> berhenti + notifikasi; manual di Windows: proses bot dimatikan paksa -> berjalan lagi < 1 menit dan pesan Telegram masuk

- [ ] **24. Hardening**
  - Rujukan: TRD bagian 8-9, PRD F-01 s.d. F-05 dan F-09 kasus gagal
  - Kerjakan: retry/timeout konsisten, tahan putus internet, tahan restart, rotasi log, saring secret dari log
  - Selesai jika: skenario manual lolos: cabut internet 5 menit, matikan MT5, restart bot saat ada posisi, PC sleep lalu bangun; tes memastikan key/token tidak muncul di log

- [ ] **25. Paket Windows & dokumentasi pakai**
  - Rujukan: TRD bagian 6
  - Kerjakan: `start.bat` final, panduan di `README.md`: pasang Python dan MT5, akun demo khusus bot dengan saldo setara rencana modal live, isi `.env` (termasuk Telegram), Task Scheduler untuk MT5 + watchdog saat login, checklist uptime (sleep, Windows Update, Algo Trading), opsi VPS Windows
  - Selesai jika: orang lain dapat memasang dan menjalankan dari nol di Windows bersih mengikuti README

- [ ] **26. Uji demo >= 4 minggu & evaluasi**
  - Rujukan: PRD bagian 3, F-07, F-08
  - Kerjakan: jalankan bot di demo; aktifkan `lessons_frozen` dan jangan ubah pengaturan risiko minimal 2 minggu sebelum akhir uji
  - Selesai jika: `live_readiness` di S-05 lolos semua syarat: >= 4 minggu, >= 30 trade, profit factor >= 1.3, max drawdown <= 10%, 0 pelanggaran batas risiko, `prompt_version` terakhir stabil >= 2 minggu dengan rata-rata R >= 0, tanpa perubahan pengaturan risiko 2 minggu terakhir. **Keputusan beralih ke live ada di owner, di luar IPD ini.**

## Definition of Done (berlaku untuk tiap langkah)
- [ ] Sesuai spesifikasi di dokumen yang dirujuk
- [ ] Tes relevan ditulis dan lolos; `ruff check .` dan `pytest` lolos
- [ ] Tidak ada secret di kode; tidak ada `print` debug tertinggal
- [ ] Tidak ada order tanpa SL/TP atau di luar kunci eksekusi; penjaga risiko tidak dilemahkan
- [ ] Logika waktu memakai `Clock`; teks bebas keluaran AI tidak masuk ke prompt mana pun
- [ ] Dokumen diperbarui bila ada keputusan yang mengubah spesifikasi

## Risiko
| Risiko | Dampak | Mitigasi |
|---|---|---|
| Kerugian saat live | Kehilangan modal | Demo dulu, penjaga live berlapis, kill switch, risiko 0.5% |
| Semua AI sepakat tetapi salah | Trade rugi | Validasi risiko deterministik, SL wajib, batas harian/mingguan, rem tambahan |
| Perilaku MT5/broker berbeda dari mock | Bug muncul saat Windows | Kontrak tes `Broker` yang sama, mock realistis, langkah [Windows] diuji manual |
| Order ganda | Risiko dobel | Kunci satu instans, kunci eksekusi, idempotensi order |
| Gap akhir pekan/rollover melewati SL | Rugi > target per trade | Diterima owner; risiko kecil per trade, maks 2 posisi, `excess_loss` dicatat |
| Feed kalender mati | Entry diblokir terus | Fail-safe disengaja; provider dapat diganti; blackout manual |
| Model AI dipensiunkan / kredit habis | Bot berhenti trading diam-diam | Kesehatan AI, banner, notifikasi Telegram |
| Biaya API membengkak | Biaya tak terduga | Panggil saat candle tutup setelah guard, `ai_calls`, `max_ai_calls_per_day` |
| Pelajaran otomatis overfitting | Bot memburuk diam-diam | Hanya memperketat, teks template, verifikasi dengan hasil hipotetis, per model, batas total, cooldown, penentang mingguan, rollback, pembekuan |
| PC sleep/restart/mati listrik | Trailing dan kill switch berhenti | Watchdog, Task Scheduler, checklist README, opsi VPS |
| Sesi kerja terputus di tengah langkah | Status campur | Satu langkah satu commit; centang hanya setelah lolos |

## Catatan & Utang Teknis
<!-- Tambahkan: tanggal - langkah - catatan/keputusan -->
- 2026-10-29 - update - Revisi 5 (audit ketiga): teks pelajaran dari template; hasil hipotetis (`paper_outcomes`) untuk verifikasi pelajaran dan scorecard model (keputusan owner); rollback hanya di job mingguan dengan mengaktifkan kembali versi lama, cooldown dan penggabungan duplikat pelajaran; skema fitur `f1` (TRD 5c); data 2000 M15 / 1000 H1; `order_check` margin dan `deviation`; kunci satu instans, kunci eksekusi, idempotensi order; thread pekerja MT5; penanda platform `MetaTrader5`; rem dan baseline tahan restart dari riwayat deal; metrik R; batas total pelajaran dan peringatan tidak ada entry; kesehatan dan anggaran AI (`ai_calls`); spread/slippage relatif ATR; `excess_loss`/`excess_risk`; blokir rutin dipisah dari `risk_events`; langkah minimum trailing; syarat kelayakan live diperketat; `settings_changes`; `Clock` dan mock realistis; F-09 notifikasi Telegram satu arah + watchdog (keputusan owner); panel "Kenapa bot tidak trading"; `DASHBOARD_PORT`; dependensi dipin. Langkah 10, 13, 19 dipecah; langkah baru 20a, 20b, 23a, 23b; total 42 langkah, estimasi ~115 jam.
- 2026-10-29 - utang - Saat live disetujui: mulai dengan risiko 0.25% per trade untuk 30 trade pertama sebelum kembali ke 0.5%. Di luar scope MVP.
- 2026-10-29 - update - Revisi 4: strategi diskresi penuh AI (keputusan owner); F-08 pelajaran AI otomatis (refleksi, usulan terstruktur, verifikasi kode, per model, kedaluwarsa, penentang mingguan silang penyedia Sabtu 00:00 UTC, rollback, pembekuan); rem tambahan F-04 (kalah beruntun, entry harian, rugi mingguan, volatilitas, cutoff Jumat); beberapa model per penyedia (`max_ai_models`, `require_provider_diversity`). Tabel baru `ai_reflections`, `ai_lessons`, `prompt_versions`. Langkah baru 11c, 21a-21e; estimasi ~87 jam.
- 2026-10-29 - init - Revisi 3 (audit kedua): buffer breakeven tanpa spread + konversi komisi, komisi pulang-pergi di rumus lot, `tick_value_loss`, aturan lintas key risiko, 1 posisi per simbol dikunci, `ai_models` menggantikan key model/aktif per penyedia, akun khusus bot (posisi tanpa magic diabaikan), validasi sisi SL/TP AI, simbol kanonik + `broker_symbol`, definisi rugi harian/max drawdown/pelanggaran, cek cakupan kalender, `market_closed`, validasi ulang spread dan sebelum retry. Langkah 5, 11, 12 dipecah (a/b); estimasi ~71 jam.
- 2026-10-29 - init - Revisi 2 (audit): rumus lot lengkap + bulat ke bawah, validasi ulang harga sebelum order, SL tidak valid -> tutup, reconnect tanpa batas, cek Algo Trading/hedging/filling, `stops_level`, hapus `symbols`, `settings` menang atas `.env`, provider AI tanpa CHECK, `min_ai_models` minimal 2, anti DNS rebinding + token di halaman, `prompt_version`, aturan `close_reason`. Keputusan owner: posisi melewati akhir pekan hanya dengan SL; korelasi USD hanya dicatat.
- 2026-10-29 - utang - Belum ada cara resmi mengubah `mode` ke `live` (API menolak). Saat live disetujui, buat perintah CLI terpisah yang menjalankan penjaga TRD 5. Di luar scope MVP.
- 2026-10-29 - init - Revisi 1: simbol fleksibel (`symbol_map`), `kill_switch_mode`, sumber kalender dijelaskan + provider/manual blackout, `min_ai_models`, ID model dapat diatur.
- 2026-10-29 - init - Dokumen dibuat. Belum ada kode. Menunggu persetujuan owner sebelum langkah 1.
