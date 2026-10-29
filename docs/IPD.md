# IPD - TradingBot AI (MT5)

> Versi: 0.1 | Diperbarui: 2026-10-29 | Merujuk: PRD, TRD, AFD, DBD, BSD

## Cara memakai
Kerjakan **satu langkah per sesi**, berurutan. Centang `[x]` hanya jika kriteria "Selesai jika" terbukti lolos. Jangan mengerjakan fitur di luar langkah yang aktif.
Langkah bertanda **[Windows]** harus diuji manual di PC Windows dengan MT5 akun demo khusus bot; di lingkungan lain, cukup lewat `MockBroker`.
**Semua pengujian dengan uang nyata dilarang** sampai kriteria PRD bagian 3 terpenuhi dan owner menyetujui eksplisit.

## Ringkasan Fase
| Fase | Tujuan | Langkah | Estimasi |
|---|---|---|---|
| 1 | Fondasi | 1-5b | ~16 jam (1.5 minggu) |
| 2 | Alur inti (analisa, AI, risiko, eksekusi) | 6-15 | ~34 jam (3.5 minggu) |
| 3 | Dashboard, jurnal & pelajaran AI | 16-21e | ~27 jam (2.5-3 minggu) |
| 4 | Polesan, hardening, uji demo | 22-26 | ~10 jam + 4 minggu uji demo berjalan |

Total pengerjaan ~87 jam (~9 minggu pada ~10 jam/minggu), lalu >= 4 minggu uji demo.

## Fase 1 - Fondasi

- [ ] **1. Setup proyek**
  - Rujukan: TRD bagian 1, 3, 4
  - Kerjakan: `pyproject.toml` (dependensi + extra `dev`: pytest, ruff), struktur folder `src/tradingbot/...`, `.env.example`, `.gitignore` (`.env`, `data/`, `logs/`), `start.bat`, `python -m tradingbot` mencetak versi dan keluar
  - Selesai jika: `pip install -e .[dev]` berhasil; `ruff check .` dan `pytest` (satu tes dummy) lolos

- [ ] **2. Database & skema**
  - Rujukan: BSD bagian 2-4, 7
  - Kerjakan: model SQLAlchemy + migrasi Alembic untuk semua tabel BSD, seed `settings` default (termasuk `ai_models` dari `.env`) dan `prompt_versions` `v1`, helper sesi
  - Selesai jika: migrasi berjalan dari nol; seed terisi; tes skema (constraint CHECK/UNIQUE) lolos

- [ ] **3. Config & penjaga mode**
  - Rujukan: TRD bagian 5, F-05 (kriteria mode live), BSD `settings` (termasuk aturan validasi lintas key)
  - Kerjakan: loader `.env` + `settings` dengan validasi batas per key dan lintas key (Pydantic), fungsi `check_live_guard(account_type)`, default paksa `demo`
  - Selesai jika: tes membuktikan: mode `live` ditolak tanpa `LIVE_ENABLED=true`; ditolak jika tipe akun tidak cocok; nilai di luar batas ditolak; `risk_per_trade_pct` x `max_open_positions` > `max_daily_loss_pct` ditolak; `min_ai_models` < 2 atau > jumlah model aktif ditolak; model aktif > `max_ai_models` ditolak; tanpa model dari salah satu penyedia saat `require_provider_diversity` = 1 ditolak; `max_weekly_loss_pct` < `max_daily_loss_pct` ditolak

- [ ] **4. Broker interface & MockBroker**
  - Rujukan: F-01, TRD bagian 2-3, 5a
  - Kerjakan: `Broker` (info akun, candle, tick/spread, info simbol termasuk `tick_size`/`tick_value_loss`/`stops_level`/`freeze_level`/status pasar, kirim order, posisi terbuka, modifikasi SL/TP, tutup posisi, riwayat deal) + `MockBroker` dengan data candle sintetis dan fill sederhana
  - Selesai jika: tes unit MockBroker lolos (order dengan SL/TP, tutup, riwayat, posisi tanpa magic)

- [ ] **5a. MT5Broker: koneksi & data [Windows]**
  - Rujukan: F-01, TRD bagian 5a, 9
  - Kerjakan: implementasi `Broker` di `broker/mt5.py`, normalisasi waktu ke UTC, pemetaan simbol via `symbol_map` + pencarian kandidat (`symbols_get`), skrip `scripts/check_mt5.py` yang mencetak akun/tipe/margin mode/filling/candle
  - Selesai jika: di Windows, skrip mencetak saldo, tipe akun DEMO, dan 300 candle M15/H1 untuk kedua simbol kanonik lewat nama broker; kontrak tes `Broker` yang sama lolos untuk Mock dan MT5

- [ ] **5b. MT5Broker: cek start, reconnect, batas broker [Windows]**
  - Rujukan: F-01, TRD bagian 5a
  - Kerjakan: cek saat start (Algo Trading aktif, akun hedging, `filling_mode`), status pasar simbol, abaikan posisi tanpa magic bot, reconnect (10 detik x 5, lalu tiap 60 detik tanpa batas, lanjut otomatis), helper validasi `stops_level`/`freeze_level`
  - Selesai jika: Algo Trading dimatikan -> start ditolak dengan pesan; mematikan MT5 memicu status terputus, menyalakan kembali setelah > 1 menit membuat bot lanjut sendiri; posisi manual di terminal tidak diambil alih; tes helper `stops_level` lolos

## Fase 2 - Alur Inti

- [ ] **6. Indikator & fitur pasar**
  - Rujukan: F-02, BSD `signals.features_json`
  - Kerjakan: EMA 20/50/200, RSI 14, ATR 14, MACD, swing high/low; fungsi `build_features(candles_m15, candles_h1)` menghasilkan dict ringkas
  - Selesai jika: tes dengan data tetap cocok nilai acuan (toleransi 1e-6); data < 300 candle ditolak dengan pesan jelas

- [ ] **7. Filter berita**
  - Rujukan: F-02, BSD `news_events`, `settings.news_block_minutes`, `settings.manual_blackouts`
  - Kerjakan: `analysis/news.py` dengan `NewsProvider` yang dapat diganti (default feed Forex Factory mingguan), httpx + timeout, simpan upsert, dukung `manual_blackouts`, `is_news_blocked(symbol, now)`, cek cakupan kalender, pemetaan simbol -> mata uang (XAUUSD: USD; EURUSD: EUR, USD). Verifikasi feed nyata dari PC Windows.
  - Selesai jika: tes: dalam `± news_block_minutes` event high -> blokir; di luar -> lolos; manual blackout -> blokir; data > 24 jam / fetch gagal / kalender tidak mencakup waktu sekarang -> blokir (`news_block`)

- [ ] **8. Antarmuka AI + adapter Claude**
  - Rujukan: F-03, TRD bagian 1, 4, 5b
  - Kerjakan: `ai/schema.py` (Pydantic: direction, confidence, sl_price, tp_price, rationale; SL/TP wajib untuk buy/sell, boleh kosong untuk hold; SL/TP sisi salah -> tidak valid), `ai/prompts.py` (dengan `prompt_version`, batas ATR/RR, aturan sisi), `AIProvider` base + registry, `claude.py` dengan output terstruktur, timeout 30 detik, temperature rendah tetap, model dari `ai_models`
  - Selesai jika: tes dengan klien palsu: balasan valid di-parse; JSON rusak / timeout / SL di sisi salah menghasilkan `AIError` terkontrol; 1 panggilan nyata manual ke Claude mengembalikan opini valid

- [ ] **9. Adapter OpenAI**
  - Rujukan: F-03, TRD bagian 5b
  - Kerjakan: `ai/openai_provider.py` dengan skema, prompt, dan timeout yang sama; model dari `ai_models` (bukan langsung dari `.env`)
  - Selesai jika: tes klien palsu setara langkah 8 lolos; 1 panggilan nyata manual valid

- [ ] **10. Konsensus & penyimpanan sinyal**
  - Rujukan: F-03, BSD `signals`, `ai_opinions`
  - Kerjakan: panggilan paralel (`asyncio.gather`) ke semua model `enabled` di `ai_models`, `consensus.py` (semua model aktif sama arah, bukan hold, conf >= `min_confidence`, jumlah model aktif >= `min_ai_models`, diversitas penyedia bila wajib, kurang -> `blocked` `insufficient_ai_models` tanpa memanggil AI), simpan `signals` (simbol kanonik, `prompt_version`) + `ai_opinions`, idempotensi per (`symbol`,`timeframe`,`bar_time`)
  - Selesai jika: tes tabel kebenaran (setuju / beda arah / satu hold / satu error / SL sisi salah / satu nonaktif / dua model satu penyedia / tanpa model OpenAI saat diversitas wajib) lolos; sinyal yang sama tidak tersimpan dua kali

- [ ] **11a. Validasi SL/TP & guard entry**
  - Rujukan: F-04, BSD `settings`
  - Kerjakan: gabung SL terjauh + TP terdekat, validasi jarak SL (`sl_atr_min`-`sl_atr_max`) dan RR (`min_rr`), guard spread, sesi, pasar tutup, maks posisi
  - Selesai jika: tes: SL di luar batas ATR ditolak; RR < `min_rr` ditolak; spread > batas -> `spread_too_wide`; di luar sesi -> `outside_session`; pasar tutup -> `market_closed`; posisi penuh -> `max_positions`

- [ ] **11b. Perhitungan lot & validasi ulang sebelum order**
  - Rujukan: F-04, TRD bagian 5a
  - Kerjakan: lot dengan rumus PRD F-04 (`tick_size`, `tick_value_loss`, 2 x `commission_per_lot`, bulat ke bawah ke `volume_step`, batas `volume_max`), fungsi validasi ulang (spread, SL/TP, lot) dengan bid/ask terbaru
  - Selesai jika: tes: lot benar untuk XAUUSD dan EURUSD (contoh tetap, termasuk kontrak 100 oz) dan risiko aktual tidak pernah > target; lot < `volume_min` -> `lot_too_small`; harga terbaru melewati SL -> `invalid_sltp`; spread melebar saat validasi ulang -> `spread_too_wide`

- [ ] **11c. Rem tambahan**
  - Rujukan: F-04 (rem tambahan), BSD `settings`, `daily_stats`, `trades`
  - Kerjakan: guard kalah beruntun + jeda, maks entry harian, rugi mingguan (dari balance Senin 00:00 UTC), lonjakan volatilitas (ATR M15 vs median 20 hari), cutoff Jumat
  - Selesai jika: tes: 3 kalah beruntun -> `consecutive_losses` selama 4 jam lalu lolos; entry ke-5 dalam sehari -> `max_entries_day`; rugi mingguan 4% -> `weekly_loss_limit` sampai Senin; ATR 3.5x median -> `volatility_shock`; Jumat 18:01 UTC -> `friday_cutoff`, Senin saat pasar buka -> lolos

- [ ] **12a. Batas rugi harian & kill switch dasar**
  - Rujukan: F-04, BSD `daily_stats`, `risk_events`, `settings.kill_switch*`
  - Kerjakan: `daily_stats` pada 00:00 UTC (`start_balance`), rugi harian = (`start_balance` - equity) / `start_balance`, pemicu otomatis, `trigger_kill_switch(reason, mode)` untuk mode `close_all`, fungsi panic (selalu tutup semua), reset manual dan reset otomatis hari berikutnya (hanya untuk pemicu batas harian)
  - Selesai jika: tes MockBroker: rugi mencapai `max_daily_loss_pct` -> kill switch ON, semua posisi bot tertutup (`close_all`), entry berikutnya diblokir, `risk_events` tercatat; reset manual dan otomatis berfungsi; kill switch manual tidak ter-reset otomatis

- [ ] **12b. Mode `protect_winners`**
  - Rujukan: F-04, F-05 (buffer breakeven), TRD bagian 5a
  - Kerjakan: di `trigger_kill_switch`: tutup posisi rugi; posisi untung -> SL ke minimal breakeven + buffer; jika SL itu tidak bisa dipasang valid (`stops_level`/`freeze_level`/sisi harga) -> tutup (`sltp_unplaceable`)
  - Selesai jika: tes MockBroker: posisi rugi tertutup; posisi untung tetap hidup dengan SL >= breakeven + buffer; posisi untung tipis yang SL-nya tidak valid ikut ditutup; posisi tanpa magic bot tidak disentuh

- [ ] **13. Eksekusi order & rekonsiliasi**
  - Rujukan: F-05, BSD `trades`
  - Kerjakan: `executor.py` (validasi ulang langkah 11b, order market + SL/TP + magic + `type_filling` dari broker, validasi ulang lalu 1 retry, status `rejected`), `reconcile.py` (sinkron `trades` dengan posisi/deal broker berdasarkan magic; ambil alih posisi ber-magic saat start dengan `risk_amount` dari SL; isi `broker_symbol`; `close_reason` sesuai aturan BSD `trades`)
  - Selesai jika: tes MockBroker: order tersimpan `open`; ditolak -> validasi ulang lalu `rejected` tanpa retry kedua; restart mengambil alih posisi ber-magic saja; posisi tertutup di broker -> `closed` dengan profit dan `close_reason` benar untuk tp/sl/breakeven/trailing/manual

- [ ] **14. Breakeven & trailing**
  - Rujukan: F-05, TRD bagian 5a
  - Kerjakan: `position_manager.py` (+1R -> SL ke breakeven + buffer, dengan buffer = komisi pulang-pergi dikonversi ke jarak harga + `breakeven_buffer_points`, tanpa spread; +1.5R -> trailing 1 x ATR; SL hanya bergerak searah menguntungkan; cek `stops_level`/`freeze_level` sebelum modifikasi)
  - Selesai jika: tes simulasi harga menunjukkan SL bergeser tepat pada ambang, berada di atas entry (BUY) / di bawah entry (SELL) sebesar buffer, tidak pernah mundur, dan keluar di level breakeven menghasilkan profit bersih >= 0 setelah komisi

- [ ] **15. Orkestrator end-to-end (demo) [Windows]**
  - Rujukan: seluruh F-01 s.d. F-05, AFD bagian 3
  - Kerjakan: `main.py` loop menunggu candle M15 tutup per simbol, memanggil seluruh pipeline, loop posisi 10 detik, logging ke `logs/bot.log`
  - Selesai jika: tes integrasi MockBroker + AI palsu menjalankan siklus penuh (buy, sell, skip, blocked); di Windows akun demo, bot berjalan >= 2 jam, setiap candle menghasilkan `signals`, tidak ada order tanpa SL/TP, semua keputusan tercatat

## Fase 3 - Dashboard & Jurnal

- [ ] **16. Web skeleton & S-01 Dashboard**
  - Rujukan: F-06, AFD S-01, DBD bagian 1-3, BSD `/api/status`
  - Kerjakan: FastAPI bind 127.0.0.1, middleware cek header `Host`, sisipkan `DASHBOARD_TOKEN` ke meta tag halaman, template dasar (header, navigasi, badge mode, tombol kill switch), `/api/status`, S-01 dengan polling 5 detik, banner "bot tidak terjangkau"
  - Selesai jika: S-01 menampilkan status nyata dari MockBroker; mematikan backend memunculkan banner; tes API status lolos; request dengan `Host: evil.com` -> 400

- [ ] **17. S-02 Sinyal & Opini AI**
  - Rujukan: F-03, F-06, AFD S-02, BSD `/api/signals`
  - Selesai jika: tabel sinyal dengan baris yang bisa diperluas memperlihatkan opini + alasan tiap model dan `block_reason`; filter simbol berfungsi

- [ ] **18. S-03 Posisi & Riwayat**
  - Rujukan: F-05, F-06, AFD S-03, BSD `/api/trades`
  - Selesai jika: tab Terbuka/Riwayat benar; tautan ke sinyal asal berfungsi; profit berwarna + teks tanda

- [ ] **19. S-04 Risiko & Pengaturan + kill switch**
  - Rujukan: F-04, F-06, AFD S-04, DBD S-04, BSD `settings`, `/api/settings`, `/api/kill-switch`, `/api/symbols/candidates`, TRD bagian 5
  - Kerjakan: form pengaturan risiko, pilih `symbol_map` dari kandidat MT5, pilih `kill_switch_mode`, editor `ai_models` (beberapa model per penyedia, tambah/aktif/nonaktif), toggle `lessons_enabled`/`lessons_frozen`, pengaturan rem tambahan, input `breakeven_buffer_points` dan `commission_per_lot`, tombol kill switch, reset, dan "Tutup semua sekarang" dengan dialog konfirmasi
  - Selesai jika: ubah risiko tersimpan dan berlaku siklus berikutnya; nilai di luar batas atau melanggar aturan lintas key ditolak dengan pesan; ubah `symbol_map` saat ada posisi terbuka -> 409; tanpa token -> 401; coba ubah `mode`/`kill_switch` lewat PUT -> 403; kill switch, reset, dan panic bekerja dengan dialog konfirmasi

- [ ] **20. Statistik jurnal & kelayakan live**
  - Rujukan: F-07, PRD bagian 3 (definisi), BSD `daily_stats`, `journal_entries`
  - Kerjakan: `journal/stats.py` (jumlah trade, win rate, profit factor, net profit, max drawdown sesuai definisi PRD), simpan harian/mingguan, fungsi `live_readiness()` terhadap kriteria PRD bagian 3 (hanya trade `account_mode = demo`, dan `prompt_version` terakhir stabil >= 2 minggu)
  - Selesai jika: tes dengan set trade tetap menghasilkan angka acuan; `live_readiness` benar untuk kasus lolos dan gagal; rugi akibat gap tidak dihitung sebagai pelanggaran

- [ ] **21. Ringkasan AI & S-05 Jurnal**
  - Rujukan: F-07, AFD S-05, BSD `/api/journal`, TRD bagian 5b
  - Kerjakan: ringkasan memakai model aktif pertama di `ai_models`
  - Selesai jika: ringkasan tersimpan dan tampil; AI gagal -> statistik tetap tampil dengan tombol coba lagi; S-05 menampilkan progres kriteria live

- [ ] **21a. Refleksi pasca-trade**
  - Rujukan: F-08, BSD `ai_reflections`, TRD 5b
  - Kerjakan: `learning/reflection.py`: saat trade `closed`, minta tiap model yang ikut memutuskan menulis refleksi; simpan; gagal -> `error` terisi
  - Selesai jika: tes AI palsu: trade tertutup menghasilkan satu refleksi per model; error tidak menghentikan rekonsiliasi; tidak ada refleksi ganda

- [ ] **21b. Usulan pelajaran & verifikasi kode**
  - Rujukan: F-08, BSD `ai_lessons`
  - Kerjakan: skema usulan terstruktur, validator (kunci fitur dikenal, hanya memperketat, `effect_value` > `min_confidence`), penghitung statistik kondisi dari `signals`/`trades`, status `pending` bila >= `lesson_min_trades`
  - Selesai jika: tes: usulan melonggarkan ditolak; kunci tidak dikenal ditolak; statistik benar pada data tetap; < 20 trade tidak menjadi pending

- [ ] **21c. Penerapan pelajaran & versi prompt**
  - Rujukan: F-03, F-08, BSD `prompt_versions`, `ai_opinions.raw_direction`/`lessons_applied`
  - Kerjakan: evaluator kondisi, efek `avoid`/`raise_confidence` pada opini model pemilik sebelum konsensus, teks pelajaran di prompt model pemilik, `prompt_versions` aktif, `lessons_enabled` = 0 -> prompt dasar
  - Selesai jika: tes: kondisi cocok -> opini model pemilik jadi hold (`avoid`) atau tidak setuju bila confidence < nilai (`raise_confidence`); model lain tidak terpengaruh; `raw_direction` dan `lessons_applied` tercatat; mematikan pelajaran langsung kembali ke prompt dasar

- [ ] **21d. Penentang mingguan, kedaluwarsa & rollback**
  - Rujukan: F-08, TRD 5b
  - Kerjakan: job `lesson_review_utc` (idempotensi per minggu): verifikasi ulang, kedaluwarsa, penentang silang penyedia, aktivasi (maks per model), versi baru berlaku Senin, rollback setelah `rollback_min_trades` bila PF memburuk, `lessons_frozen` hanya mencatat
  - Selesai jika: tes jam palsu: penentang `reject` -> pending `rejected` / aktif `disabled`; penentang error -> tidak ada perubahan; versi baru dibuat paling banyak sekali per minggu; PF memburuk setelah 15 trade -> `rolled_back` dan versi sebelumnya aktif; frozen -> status tidak berubah

- [ ] **21e. UI pelajaran (S-05) & pengaturan (S-04)**
  - Rujukan: F-08, AFD S-04/S-05, DBD S-04/S-05, BSD `/api/lessons`, `/api/prompt-versions`
  - Selesai jika: S-05 menampilkan pelajaran per model dengan status, kondisi, efek, bukti, dan catatan penentang; riwayat versi prompt tampil; toggle di S-04 berlaku pada siklus berikutnya

## Fase 4 - Polesan, Hardening & Uji Demo

- [ ] **22. State kosong/loading/error semua layar**
  - Rujukan: AFD bagian 5, DBD bagian 3
  - Selesai jika: tiap layar S-01 s.d. S-05 menampilkan keempat state sesuai tabel AFD (diverifikasi manual + tes render)

- [ ] **23. Aksesibilitas & responsivitas**
  - Rujukan: DBD bagian 4-5
  - Selesai jika: navigasi dan aksi bisa lewat keyboard; kontras >= 4.5:1; tampilan tidak pecah pada lebar 360px; arah buy/sell punya teks

- [ ] **24. Hardening**
  - Rujukan: TRD bagian 8-9, PRD F-01 s.d. F-05 kasus gagal
  - Kerjakan: retry/timeout konsisten, tahan putus internet, tahan restart, rotasi log, saring API key dari log
  - Selesai jika: skenario manual lolos: cabut internet 5 menit, matikan MT5, restart bot saat ada posisi; tes memastikan key tidak muncul di log

- [ ] **25. Paket Windows & dokumentasi pakai**
  - Rujukan: TRD bagian 6
  - Kerjakan: `start.bat`, panduan singkat di `README.md` (pasang Python, MT5, akun demo khusus bot, isi `.env`, jalankan), daftar periksa sebelum menjalankan
  - Selesai jika: orang lain dapat memasang dan menjalankan dari nol di Windows bersih mengikuti README

- [ ] **26. Uji demo >= 4 minggu & evaluasi**
  - Rujukan: PRD bagian 3, F-07
  - Kerjakan: aktifkan `lessons_frozen` minimal 2 minggu sebelum akhir uji
  - Selesai jika: `prompt_version` terakhir berlaku >= 2 minggu tanpa perubahan; S-05 menunjukkan >= 4 minggu, >= 30 trade, profit factor >= 1.3, max drawdown <= 10%, 0 pelanggaran batas risiko. **Keputusan beralih ke live ada di owner, di luar IPD ini.**

## Definition of Done (berlaku untuk tiap langkah)
- [ ] Sesuai spesifikasi di dokumen yang dirujuk
- [ ] Tes relevan ditulis dan lolos; `ruff check .` dan `pytest` lolos
- [ ] Tidak ada secret di kode; tidak ada `print` debug tertinggal
- [ ] Tidak ada order tanpa SL/TP; penjaga risiko tidak dilemahkan
- [ ] Dokumen diperbarui bila ada keputusan yang mengubah spesifikasi

## Risiko
| Risiko | Dampak | Mitigasi |
|---|---|---|
| Kerugian saat live | Kehilangan modal | Demo dulu, penjaga live berlapis, kill switch, risiko 0.5% |
| Semua AI sepakat tetapi salah | Trade rugi | Validasi risiko deterministik, SL wajib, batas harian |
| Perilaku MT5/broker berbeda dari mock | Bug muncul saat Windows | Kontrak tes `Broker` yang sama, langkah [Windows] diuji manual |
| Gap akhir pekan/rollover melewati SL | Rugi > target per trade | Diterima owner; risiko kecil per trade, maks 2 posisi |
| Feed kalender mati | Entry diblokir terus | Fail-safe disengaja; provider dapat diganti; blackout manual |
| Biaya API membengkak | Biaya tak terduga | Panggil saat candle tutup setelah guard, idempotensi per candle, log jumlah panggilan |
| Pelajaran otomatis overfitting | Bot memburuk diam-diam | Hanya memperketat, verifikasi kode, per model, penentang mingguan, rollback, pembekuan |
| Sesi kerja terputus di tengah langkah | Status campur | Satu langkah satu commit; centang hanya setelah lolos |

## Catatan & Utang Teknis
<!-- Tambahkan: tanggal - langkah - catatan/keputusan -->
- 2026-10-29 - update - Revisi 4: strategi diskresi penuh AI (keputusan owner); F-08 pelajaran AI otomatis (refleksi, usulan terstruktur, verifikasi kode, per model, kedaluwarsa, penentang mingguan silang penyedia Sabtu 00:00 UTC, rollback, pembekuan); rem tambahan F-04 (kalah beruntun, entry harian, rugi mingguan, volatilitas, cutoff Jumat); beberapa model per penyedia (`max_ai_models`, `require_provider_diversity`). Tabel baru `ai_reflections`, `ai_lessons`, `prompt_versions`. Langkah baru 11c, 21a-21e; estimasi ~87 jam.
- 2026-10-29 - init - Revisi 3 (audit kedua): buffer breakeven tanpa spread + konversi komisi, komisi pulang-pergi di rumus lot, `tick_value_loss`, aturan lintas key risiko, 1 posisi per simbol dikunci, `ai_models` menggantikan key model/aktif per penyedia, akun khusus bot (posisi tanpa magic diabaikan), validasi sisi SL/TP AI, simbol kanonik + `broker_symbol`, definisi rugi harian/max drawdown/pelanggaran, cek cakupan kalender, `market_closed`, validasi ulang spread dan sebelum retry. Langkah 5, 11, 12 dipecah (a/b); estimasi ~71 jam.
- 2026-10-29 - init - Revisi 2 (audit): rumus lot lengkap + bulat ke bawah, validasi ulang harga sebelum order, SL tidak valid -> tutup, reconnect tanpa batas, cek Algo Trading/hedging/filling, `stops_level`, hapus `symbols`, `settings` menang atas `.env`, provider AI tanpa CHECK, `min_ai_models` minimal 2, anti DNS rebinding + token di halaman, `prompt_version`, aturan `close_reason`. Keputusan owner: posisi melewati akhir pekan hanya dengan SL; korelasi USD hanya dicatat.
- 2026-10-29 - utang - Belum ada cara resmi mengubah `mode` ke `live` (API menolak). Saat live disetujui, buat perintah CLI terpisah yang menjalankan penjaga TRD 5. Di luar scope MVP.
- 2026-10-29 - init - Revisi 1: simbol fleksibel (`symbol_map`), `kill_switch_mode`, sumber kalender dijelaskan + provider/manual blackout, `min_ai_models`, ID model dapat diatur.
- 2026-10-29 - init - Dokumen dibuat. Belum ada kode. Menunggu persetujuan owner sebelum langkah 1.
