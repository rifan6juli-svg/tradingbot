# IPD - TradingBot AI (MT5)

> Versi: 0.1 | Diperbarui: 2026-10-29 | Merujuk: PRD, TRD, AFD, DBD, BSD

## Cara memakai
Kerjakan **satu langkah per sesi**, berurutan. Centang `[x]` hanya jika kriteria "Selesai jika" terbukti lolos. Jangan mengerjakan fitur di luar langkah yang aktif.
Langkah bertanda **[Windows]** harus diuji manual di PC Windows dengan MT5 akun demo; di lingkungan lain, cukup lewat `MockBroker`.
**Semua pengujian dengan uang nyata dilarang** sampai kriteria PRD bagian 3 terpenuhi dan owner menyetujui eksplisit.

## Ringkasan Fase
| Fase | Tujuan | Langkah | Estimasi |
|---|---|---|---|
| 1 | Fondasi | 1-5 | ~12 jam (1-1.5 minggu) |
| 2 | Alur inti (analisa, AI, risiko, eksekusi) | 6-15 | ~25 jam (2.5 minggu) |
| 3 | Dashboard & jurnal | 16-21 | ~14 jam (1.5 minggu) |
| 4 | Polesan, hardening, uji demo | 22-26 | ~10 jam + 4 minggu uji demo berjalan |

Total pengerjaan ~61 jam (~6 minggu pada ~10 jam/minggu), lalu >= 4 minggu uji demo.

## Fase 1 - Fondasi

- [ ] **1. Setup proyek**
  - Rujukan: TRD bagian 1, 3, 4
  - Kerjakan: `pyproject.toml` (dependensi + extra `dev`: pytest, ruff), struktur folder `src/tradingbot/...`, `.env.example`, `.gitignore` (`.env`, `data/`, `logs/`), `start.bat`, `python -m tradingbot` mencetak versi dan keluar
  - Selesai jika: `pip install -e .[dev]` berhasil; `ruff check .` dan `pytest` (satu tes dummy) lolos

- [ ] **2. Database & skema**
  - Rujukan: BSD bagian 2-4, 7
  - Kerjakan: model SQLAlchemy + migrasi Alembic untuk semua tabel BSD, seed `settings` default, helper sesi
  - Selesai jika: migrasi berjalan dari nol; seed terisi; tes skema (constraint CHECK/UNIQUE) lolos

- [ ] **3. Config & penjaga mode**
  - Rujukan: TRD bagian 5, F-05 (kriteria mode live), BSD `settings`
  - Kerjakan: loader `.env` + `settings` dengan validasi batas (Pydantic), fungsi `check_live_guard(account_type)`, default paksa `demo`
  - Selesai jika: tes membuktikan: mode `live` ditolak tanpa `LIVE_ENABLED=true`; ditolak jika tipe akun tidak cocok; nilai di luar batas ditolak

- [ ] **4. Broker interface & MockBroker**
  - Rujukan: F-01, TRD bagian 2-3
  - Kerjakan: `Broker` (info akun, candle, tick/spread, info simbol, kirim order, posisi terbuka, modifikasi SL/TP, tutup posisi, riwayat deal) + `MockBroker` dengan data candle sintetis dan fill sederhana
  - Selesai jika: tes unit MockBroker lolos (order dengan SL/TP, tutup, riwayat)

- [ ] **5. MT5Broker [Windows]**
  - Rujukan: F-01, TRD bagian 9
  - Kerjakan: implementasi `Broker` di `broker/mt5.py`, normalisasi waktu ke UTC, pemetaan simbol via `symbol_map` + pencarian kandidat (`symbols_get`), reconnect (10 detik, maks 5 kali), skrip `scripts/check_mt5.py` yang mencetak akun/tipe/candle
  - Selesai jika: di Windows, skrip mencetak saldo, tipe akun DEMO, dan 300 candle M15/H1 XAUUSD dan EURUSD; mematikan MT5 memicu status terputus dan reconnect; kontrak tes `Broker` yang sama lolos untuk Mock dan MT5

## Fase 2 - Alur Inti

- [ ] **6. Indikator & fitur pasar**
  - Rujukan: F-02, BSD `signals.features_json`
  - Kerjakan: EMA 20/50/200, RSI 14, ATR 14, MACD, swing high/low; fungsi `build_features(candles_m15, candles_h1)` menghasilkan dict ringkas
  - Selesai jika: tes dengan data tetap cocok nilai acuan (toleransi 1e-6); data < 300 candle ditolak dengan pesan jelas

- [ ] **7. Filter berita**
  - Rujukan: F-02, BSD `news_events`, `settings.news_block_minutes`
  - Kerjakan: `analysis/news.py` dengan `NewsProvider` yang dapat diganti (default feed Forex Factory mingguan), httpx + timeout, simpan upsert, dukung `manual_blackouts`, `is_news_blocked(symbol, now)`, pemetaan simbol -> mata uang (XAUUSD: USD; EURUSD: EUR, USD)
  - Selesai jika: tes: dalam +-30 menit event high -> blokir; di luar -> lolos; data > 24 jam / fetch gagal -> blokir (`news_block`)

- [ ] **8. Antarmuka AI + adapter Claude**
  - Rujukan: F-03, TRD bagian 1, 4
  - Kerjakan: `ai/schema.py` (Pydantic: direction, confidence, sl_price, tp_price, rationale), `ai/prompts.py`, `AIProvider` base + registry (penyedia baru tanpa ubah konsensus), `claude.py` dengan output terstruktur, timeout 30 detik, ID model dari konfigurasi
  - Selesai jika: tes dengan klien palsu: balasan valid di-parse; JSON rusak / timeout menghasilkan `AIError` terkontrol; 1 panggilan nyata manual ke Claude mengembalikan opini valid

- [ ] **9. Adapter OpenAI**
  - Rujukan: F-03
  - Kerjakan: `ai/openai_provider.py` dengan skema, prompt, dan timeout yang sama; ID model dari `OPENAI_MODEL`; kedua penyedia dapat diaktifkan/dinonaktifkan terpisah
  - Selesai jika: tes klien palsu setara langkah 8 lolos; 1 panggilan nyata manual valid

- [ ] **10. Konsensus & penyimpanan sinyal**
  - Rujukan: F-03, BSD `signals`, `ai_opinions`
  - Kerjakan: panggilan paralel (`asyncio.gather`), `consensus.py` (semua model aktif sama arah, bukan hold, conf >= `min_confidence`, jumlah model aktif >= `min_ai_models`), simpan `signals` + `ai_opinions`, idempotensi per (`symbol`,`timeframe`,`bar_time`)
  - Selesai jika: tes tabel kebenaran (setuju / beda arah / satu hold / satu error / satu nonaktif) lolos; sinyal yang sama tidak tersimpan dua kali

- [ ] **11. Risk manager: SL/TP & lot**
  - Rujukan: F-04, BSD `settings`
  - Kerjakan: gabung SL terjauh + TP terdekat, validasi jarak SL (ATR) dan RR, hitung lot dari risiko% dengan `volume_step/min/max`, guard spread dan sesi
  - Selesai jika: tes: SL di luar 0.8-3.0 x ATR ditolak; RR < 1.5 ditolak; lot terhitung benar untuk XAUUSD dan EURUSD (contoh tetap); lot < min diblokir (`lot_too_small`)

- [ ] **12. Batas harian & kill switch**
  - Rujukan: F-04, BSD `daily_stats`, `risk_events`
  - Kerjakan: `daily_stats` awal hari UTC, hitung rugi harian (realized + floating), pemicu otomatis, fungsi `trigger_kill_switch(reason, mode)` (`protect_winners`: tutup yang rugi, SL ke minimal breakeven untuk yang untung; `close_all`: tutup semua; set `settings.kill_switch`), tombol panic tutup semua, reset manual dan otomatis hari berikutnya
  - Selesai jika: tes MockBroker: rugi mencapai 2% -> mode `protect_winners`: posisi rugi tertutup, posisi untung tetap hidup dengan SL >= breakeven; mode `close_all`: semua tertutup; entry berikutnya diblokir, `risk_events` tercatat; reset berfungsi

- [ ] **13. Eksekusi order & rekonsiliasi**
  - Rujukan: F-05, BSD `trades`
  - Kerjakan: `executor.py` (order market + SL/TP + magic, 1 retry, status `rejected`), `reconcile.py` (sinkron `trades` dengan posisi/deal broker; ambil alih posisi ber-magic saat start)
  - Selesai jika: tes MockBroker: order tersimpan `open`; ditolak -> `rejected` tanpa retry kedua; restart mengambil alih posisi; posisi tertutup di broker -> `closed` dengan profit dan `close_reason`

- [ ] **14. Breakeven & trailing**
  - Rujukan: F-05
  - Kerjakan: `position_manager.py` (+1R -> SL ke breakeven + buffer spread/komisi/`breakeven_buffer_points`; +1.5R -> trailing 1 x ATR; SL hanya bergerak searah menguntungkan)
  - Selesai jika: tes simulasi harga menunjukkan SL bergeser tepat pada ambang, berada di atas entry (BUY) / di bawah entry (SELL) sebesar buffer, dan tidak pernah mundur

- [ ] **15. Orkestrator end-to-end (demo) [Windows]**
  - Rujukan: seluruh F-01 s.d. F-05, AFD bagian 3
  - Kerjakan: `main.py` loop menunggu candle M15 tutup per simbol, memanggil seluruh pipeline, loop posisi 10 detik, logging ke `logs/bot.log`
  - Selesai jika: tes integrasi MockBroker + AI palsu menjalankan siklus penuh (buy, sell, skip, blocked); di Windows akun demo, bot berjalan >= 2 jam, setiap candle menghasilkan `signals`, tidak ada order tanpa SL/TP, semua keputusan tercatat

## Fase 3 - Dashboard & Jurnal

- [ ] **16. Web skeleton & S-01 Dashboard**
  - Rujukan: F-06, AFD S-01, DBD bagian 1-3, BSD `/api/status`
  - Kerjakan: FastAPI bind 127.0.0.1, template dasar (header, navigasi, badge mode, tombol kill switch), `/api/status`, S-01 dengan polling 5 detik, banner "bot tidak terjangkau"
  - Selesai jika: S-01 menampilkan status nyata dari MockBroker; mematikan backend memunculkan banner; tes API status lolos

- [ ] **17. S-02 Sinyal & Opini AI**
  - Rujukan: F-03, F-06, AFD S-02, BSD `/api/signals`
  - Selesai jika: tabel sinyal dengan baris yang bisa diperluas memperlihatkan opini + alasan tiap AI dan `block_reason`; filter simbol berfungsi

- [ ] **18. S-03 Posisi & Riwayat**
  - Rujukan: F-05, F-06, AFD S-03, BSD `/api/trades`
  - Selesai jika: tab Terbuka/Riwayat benar; tautan ke sinyal asal berfungsi; profit berwarna + teks tanda

- [ ] **19. S-04 Risiko & Pengaturan + kill switch**
  - Rujukan: F-04, F-06, AFD S-04, BSD `settings`, `/api/settings`, `/api/kill-switch`, TRD bagian 5
  - Kerjakan tambahan: pilih `symbol_map` dari kandidat MT5, pilih `kill_switch_mode`, atur model AI aktif dan ID model
  - Tambahan: input `breakeven_buffer_points`
  - Selesai jika: ubah risiko tersimpan dan berlaku siklus berikutnya; nilai di luar batas ditolak dengan pesan; tanpa token -> 401; coba set `mode=live` -> 403; kill switch dan reset dengan dialog konfirmasi bekerja

- [ ] **20. Statistik jurnal & kelayakan live**
  - Rujukan: F-07, BSD `daily_stats`, `journal_entries`
  - Kerjakan: `journal/stats.py` (jumlah trade, win rate, profit factor, net profit, max drawdown), simpan harian/mingguan, fungsi `live_readiness()` terhadap kriteria PRD bagian 3
  - Selesai jika: tes dengan set trade tetap menghasilkan angka acuan; `live_readiness` benar untuk kasus lolos dan gagal

- [ ] **21. Ringkasan AI & S-05 Jurnal**
  - Rujukan: F-07, AFD S-05, BSD `/api/journal`
  - Selesai jika: ringkasan tersimpan dan tampil; AI gagal -> statistik tetap tampil dengan tombol coba lagi; S-05 menampilkan progres kriteria live

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
  - Kerjakan: `start.bat`, panduan singkat di `README.md` (pasang Python, MT5, isi `.env`, jalankan), daftar periksa sebelum menjalankan
  - Selesai jika: orang lain dapat memasang dan menjalankan dari nol di Windows bersih mengikuti README

- [ ] **26. Uji demo >= 4 minggu & evaluasi**
  - Rujukan: PRD bagian 3, F-07
  - Selesai jika: S-05 menunjukkan >= 4 minggu, >= 30 trade, profit factor >= 1.3, max drawdown <= 10%, 0 pelanggaran batas risiko. **Keputusan beralih ke live ada di owner, di luar IPD ini.**

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
| Dua AI sepakat tetapi salah | Trade rugi | Validasi risiko deterministik, SL wajib, batas harian |
| Perilaku MT5/broker berbeda dari mock | Bug muncul saat Windows | Kontrak tes `Broker` yang sama, langkah [Windows] diuji manual |
| Feed kalender mati | Entry diblokir terus | Fail-safe disengaja; adapter mudah diganti |
| Biaya API membengkak | Biaya tak terduga | Panggil saat candle tutup, log jumlah panggilan |
| Sesi kerja terputus di tengah langkah | Status campur | Satu langkah satu commit; centang hanya setelah lolos |

## Catatan & Utang Teknis
<!-- Tambahkan: tanggal - langkah - catatan/keputusan -->
- 2026-10-29 - init - Revisi 1: simbol fleksibel (`symbol_map`), `kill_switch_mode`, sumber kalender dijelaskan + provider/manual blackout, `min_ai_models`, ID model dapat diatur.
- 2026-10-29 - init - Dokumen dibuat. Belum ada kode. Menunggu persetujuan owner sebelum langkah 1.
