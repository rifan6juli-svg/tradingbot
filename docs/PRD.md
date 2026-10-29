# PRD - TradingBot AI (MT5)

> Versi: 0.1 | Diperbarui: 2026-10-29 | Status: Draft (menunggu persetujuan)

## 1. Ringkasan
Bot trading otomatis untuk Windows yang terhubung ke MetaTrader 5. Beberapa model AI (Claude dan OpenAI) menganalisa data pasar XAUUSD dan EURUSD, dan order hanya dieksekusi jika **semua** model setuju arah yang sama serta lolos batas risiko. Pengguna memantau dan mengontrol bot lewat dashboard web lokal. Tahap awal: **akun demo saja**.

## 2. Masalah
- Masalah: analisa manual lambat, emosional, dan tidak konsisten; satu AI saja bisa salah atau berhalusinasi.
- Dialami oleh: trader ritel individu (pengguna tunggal).
- Cara sekarang: analisa chart manual, entry manual, jurnal manual.

## 3. Tujuan & Metrik Sukses
| Tujuan | Metrik | Target |
|---|---|---|
| Bot aman | Pelanggaran batas risiko (rugi harian, maks posisi, lot) | 0 kejadian |
| Bot stabil | Siklus keputusan berjalan tanpa crash di demo | >= 4 minggu berturut-turut |
| Hasil layak uji live | Di demo: jumlah trade / profit factor / max drawdown | >= 30 trade / >= 1.3 / <= 10% |
| Responsif | Waktu dari penutupan candle M15 sampai order terkirim | <= 60 detik |
| Transparan | Setiap keputusan tersimpan beserta alasan tiap AI | 100% sinyal |

"Sudah jadi" = semua fitur P0 lolos di akun demo, dan metrik di atas tercapai sebelum mode live boleh dipertimbangkan.

## 4. Pengguna
| Peran | Deskripsi | Kebutuhan utama |
|---|---|---|
| Trader (owner) | Satu orang, menjalankan bot di PC Windows sendiri | Bot otomatis, batas risiko ketat, bisa menghentikan kapan saja, melihat alasan tiap keputusan |

Tidak ada login multi-user. Dashboard hanya bisa diakses dari `127.0.0.1`.

## 5. Fitur MVP
Prioritas: P0 = wajib rilis, P1 = sebaiknya ada, P2 = jika sempat.

| ID | Fitur | Prioritas | User story |
|---|---|---|---|
| F-01 | Koneksi MT5 & data pasar | P0 | Sebagai trader, saya ingin bot terhubung ke MT5 dan mengambil candle/harga/info akun, agar analisa memakai data nyata |
| F-02 | Analisa teknikal & filter berita | P0 | Sebagai trader, saya ingin indikator dihitung otomatis dan trading diblokir di sekitar berita high-impact, agar entry tidak ceroboh |
| F-03 | Panel multi-AI & konsensus | P0 | Sebagai trader, saya ingin Claude dan OpenAI menilai setup secara independen dan order hanya jalan jika semua setuju, agar kesalahan satu AI tidak langsung jadi order |
| F-04 | Manajemen risiko & kill switch | P0 | Sebagai trader, saya ingin lot dihitung dari % risiko dan ada batas rugi harian + tombol stop, agar kerugian terbatas |
| F-05 | Eksekusi order & manajemen posisi | P0 | Sebagai trader, saya ingin order terkirim ke MT5 dengan SL/TP dan posisi dikelola (breakeven/trailing), agar bot benar-benar bekerja otomatis |
| F-06 | Dashboard web lokal | P0 | Sebagai trader, saya ingin melihat status, sinyal, posisi, dan mengubah pengaturan dari browser |
| F-07 | Jurnal & evaluasi performa | P1 | Sebagai trader, saya ingin statistik dan ringkasan AI harian/mingguan, agar bisa menilai kelayakan bot |

### Acceptance Criteria
**F-01 Koneksi MT5 & data pasar**
- [ ] Bot terhubung ke terminal MT5 yang sedang berjalan dan membaca saldo, equity, tipe akun (demo/real).
- [ ] Mengambil >= 300 candle terakhir untuk M15 dan H1 per simbol (XAUUSD, EURUSD).
- [ ] Nama simbol broker fleksibel: tiap simbol kanonik (`XAUUSD`, `EURUSD`) dipetakan ke nama broker lewat `symbol_map` (mis. `XAUUSDm`, `GOLD`). Saat start, bot mencari kandidat di MT5 dan mengusulkan pemetaan; owner mengonfirmasi/mengubahnya di S-04. Bot menolak start jika simbol belum terpetakan.
- [ ] Saat start, bot memeriksa: Algo Trading aktif di terminal, akun bertipe **hedging** (netting ditolak), dan mode pengisian order (`filling_mode`) yang didukung simbol; gagal salah satu -> bot menolak start dengan pesan jelas.
- [ ] Kasus gagal: terminal mati/putus -> coba sambung ulang tiap 10 detik (5 kali), lalu tiap 60 detik tanpa batas; status "terputus" di dashboard; tidak ada order dikirim selama terputus; otomatis lanjut saat tersambung kembali (posisi tetap terlindungi SL/TP di server broker).

**F-02 Analisa teknikal & filter berita**
- [ ] Menghitung EMA 20/50/200, RSI 14, ATR 14, MACD, serta level swing high/low terakhir, pada M15 dan H1.
- [ ] Kalender ekonomi high-impact (mata uang terkait simbol; USD untuk XAUUSD) diambil minimal tiap 6 jam dan disimpan. Sumber lewat `NewsProvider` yang dapat diganti (default: feed JSON Forex Factory mingguan yang tidak resmi); owner juga bisa menambah jendela blokir manual (`manual_blackouts`) untuk berita penting.
- [ ] Tidak ada entry baru dari 30 menit sebelum sampai 30 menit sesudah berita high-impact terkait.
- [ ] Kasus gagal: data kalender lebih tua dari 24 jam atau gagal diambil -> entry diblokir (fail-safe), tercatat di `risk_events`.

**F-03 Panel multi-AI & konsensus**
- [ ] Setiap candle M15 yang ditutup, untuk tiap simbol, bot mengirim paket fitur pasar ke Claude dan OpenAI secara paralel.
- [ ] Setiap AI wajib membalas JSON terstruktur: `direction` (buy/sell/hold), `confidence` (0-1), `sl_price`, `tp_price`, `rationale`.
- [ ] Claude dan OpenAI sama-sama didukung; ID model tiap penyedia dapat diatur (`.env`/pengaturan), dan tiap penyedia dapat diaktifkan/dinonaktifkan. Penyedia baru bisa ditambahkan tanpa mengubah logika konsensus.
- [ ] Konsensus "eksekusi" hanya jika SEMUA model aktif: arah sama (bukan hold) dan `confidence` >= `min_confidence` (default 0.6), dengan jumlah model aktif >= `min_ai_models` (minimal 2, tidak bisa diturunkan).
- [ ] Setiap panggilan AI memakai temperature rendah yang tetap dan mencatat `prompt_version`, agar keputusan dapat diaudit.
- [ ] Kasus gagal: satu model timeout (> 30 detik), error, atau JSON tidak valid -> dihitung tidak setuju, hasil `skip`, error tersimpan.
- [ ] Setiap sinyal dan tiap opini AI tersimpan lengkap dengan alasan.

**F-04 Manajemen risiko & kill switch**
- [ ] Lot = uang risiko / ((jarak SL / `tick_size`) x `tick_value` + komisi per lot), dengan uang risiko = balance x `risk_per_trade_pct`. Selalu **dibulatkan ke bawah** ke `volume_step`, dibatasi `volume_max`; jika < `volume_min` -> diblokir (`lot_too_small`), tidak pernah dinaikkan.
- [ ] Default: risiko 0.5% per trade, maks rugi harian 2%, maks 2 posisi terbuka total, maks 1 posisi per simbol.
- [ ] SL/TP divalidasi: jarak SL `sl_atr_min`-`sl_atr_max` x ATR (default 0.8-3.0), rasio reward:risk >= `min_rr` (default 1.5); di luar itu -> sinyal diblokir.
- [ ] Validasi SL/TP dan perhitungan lot diulang memakai bid/ask terbaru tepat sebelum order dikirim; jika harga sudah melewati SL/TP atau tidak lagi valid -> diblokir (`invalid_sltp`).
- [ ] Blokir entry jika spread > batas per simbol, atau di luar sesi trading (default 07:00-20:00 UTC).
- [ ] Jika rugi harian (realized + floating, dari balance awal hari) mencapai batas -> kill switch aktif otomatis: tidak ada entry baru sampai hari berikutnya (UTC) atau direset manual. Perlakuan posisi terbuka diatur `kill_switch_mode`:
  - `protect_winners` (default): posisi rugi ditutup; posisi yang sedang untung tidak ditutup paksa, SL-nya dikunci minimal breakeven + buffer, trailing tetap berjalan sampai kena SL/TP. Jika SL tersebut tidak bisa dipasang secara valid (di atas bid untuk BUY / di bawah ask untuk SELL, atau melanggar `stops_level`/`freeze_level`), posisi ditutup.
  - `close_all`: semua posisi ditutup segera.
- [ ] Tombol kill switch manual di dashboard memakai `kill_switch_mode` yang sama; tersedia juga tombol terpisah "Tutup semua sekarang" (panic) yang selalu menutup semua posisi.

**F-05 Eksekusi order & manajemen posisi**
- [ ] Order market dikirim dengan SL dan TP terpasang sejak awal; magic number khusus bot.
- [ ] Pada +1R, SL digeser ke breakeven + buffer (spread + komisi per lot + `breakeven_buffer_points`, agar keluar di breakeven tidak rugi); setelah +1.5R, trailing stop berjarak 1 x ATR. SL hanya bergerak ke arah menguntungkan. Setiap modifikasi SL wajib menghormati `stops_level`/`freeze_level` broker.
- [ ] Posisi dibiarkan terbuka melewati rollover dan akhir pekan, hanya dilindungi SL/TP (keputusan owner; lihat Risiko).
- [ ] Status posisi di database selalu sinkron dengan MT5 (rekonsiliasi tiap siklus dan saat startup).
- [ ] Kasus gagal: order ditolak broker/requote -> maks 1 retry, jika tetap gagal tercatat `rejected`, tidak diulang pada candle yang sama.
- [ ] Mode `live` hanya jalan jika semua penjaga lolos (lihat TRD bagian 5); default dan paksa `demo`.

**F-06 Dashboard web lokal**
- [ ] Menampilkan: status bot, mode, koneksi MT5, saldo/equity, P/L hari ini, posisi terbuka, sinyal terakhir + opini tiap AI.
- [ ] Bisa mengubah parameter risiko, daftar simbol, model AI aktif; perubahan tersimpan dan berlaku pada siklus berikutnya.
- [ ] Tombol kill switch + tombol reset.
- [ ] Kasus gagal: backend mati -> halaman menampilkan banner "bot tidak terjangkau".

**F-07 Jurnal & evaluasi performa**
- [ ] Statistik harian/mingguan: jumlah trade, win rate, profit factor, net profit, max drawdown.
- [ ] Ringkasan teks dari AI per periode (terpisah dari keputusan trading), tersimpan.
- [ ] Menampilkan status terhadap kriteria kelayakan live (bagian 3).

## 6. Di Luar Scope (jangan dikerjakan)
- Pasar selain forex/emas di MT5 (kripto, saham), instrumen selain XAUUSD dan EURUSD.
- Backtesting engine, optimasi parameter otomatis, machine learning/training sendiri.
- Pending order (limit/stop), hedging, grid, martingale, averaging down.
- Multi-akun, multi-user, login, akses dashboard dari jaringan/internet.
- Notifikasi Telegram/email/push; aplikasi mobile.
- Eksekusi di akun live selama kriteria demo belum terpenuhi dan belum disetujui eksplisit oleh owner.
- AI mengelola posisi setelah entry (manajemen posisi memakai aturan tetap F-05).

## 7. Kebutuhan Non-Fungsional
- Performa: siklus keputusan (data -> AI -> order) <= 60 detik setelah candle M15 ditutup; dashboard termuat < 2 detik.
- Keamanan & privasi: API key hanya di `.env`; dashboard hanya `127.0.0.1` dan menolak header `Host` selain `127.0.0.1:8000`/`localhost:8000` (anti DNS rebinding); aksi ubah/kontrol butuh header token lokal; log tidak memuat API key.
- Keandalan: bot pulih otomatis dari restart (rekonsiliasi posisi) dan dari putus koneksi MT5/internet.
- Platform: Windows 10/11 64-bit, MT5 terpasang, Python 3.11, browser modern (Chrome/Edge) untuk dashboard.
- Aksesibilitas: kontras teks >= 4.5:1, dapat dipakai keyboard.

## 8. Asumsi, Risiko, Dependensi
- [ASUMSI] Broker menyediakan emas dan EURUSD dengan nama apa pun; pemetaan lewat `symbol_map` (F-01).
- [ASUMSI] Pengguna sudah punya akun demo MT5 dan API key Anthropic + OpenAI.
- Kalender ekonomi: default feed JSON mingguan Forex Factory (`nfs.faireconomy.media`), gratis tetapi **tidak resmi**, tanpa jaminan layanan, hanya minggu berjalan. Bisa mati/berubah tanpa pemberitahuan; karena itu ada fail-safe, provider yang dapat diganti, dan jendela blokir manual. Belum diverifikasi dari lingkungan pengembangan ini (jaringan diblokir); diuji di langkah 7.
- [ASUMSI] Model dipanggil hanya saat candle M15 ditutup (bukan tiap tick) untuk mengendalikan biaya API; estimasi ~210 panggilan/hari (2 simbol x ~52 candle dalam sesi 07:00-20:00 UTC x 2 model, lebih sedikit karena guard memblokir sebelum AI dipanggil).
- Kill switch: lihat F-04 (`protect_winners` default, `close_all` opsional).
- [ASUMSI] Jika beberapa model memberi SL/TP berbeda: SL dipilih yang terjauh (valid), TP yang terdekat.
- [ASUMSI] Kriteria kelayakan live: >= 30 trade, profit factor >= 1.3, max drawdown <= 10%, 0 pelanggaran batas risiko, >= 4 minggu.
- Risiko: AI keliru atau halusinasi -> mitigasi: konsensus bulat, validasi SL/TP deterministik, batas risiko di luar AI.
- Risiko: kerugian finansial nyata saat live -> mitigasi: demo dulu, penjaga mode live berlapis, kill switch.
- Risiko: tidak ada jaminan profit; hasil demo tidak menjamin hasil live (slippage, spread).
- Risiko (diterima owner): posisi dibiarkan melewati rollover (~21:00-22:00 UTC, spread melebar) dan akhir pekan; gap harga saat pasar buka dapat melewati SL sehingga rugi per trade > `risk_per_trade_pct` dan rugi harian > batas. Mitigasi: risiko kecil per trade, maks 2 posisi.
- Risiko (diterima owner, hanya dicatat): XAUUSD dan EURUSD sama-sama berlawanan dengan USD; dua posisi searah terhadap USD ~ menggandakan eksposur USD (maks 1% total pada default).
- Catatan kriteria live: >= 30 trade dengan profit factor >= 1.3 adalah gerbang minimum, bukan bukti statistik bahwa strategi menguntungkan; dengan filter konsensus bulat, 30 trade bisa butuh > 4 minggu.
- Dependensi: terminal MT5 + paket Python `MetaTrader5` (hanya Windows), API Anthropic, API OpenAI, feed kalender ekonomi.

## 9. Pertanyaan Terbuka
- Nama broker (pemetaan simbol diatur fleksibel, lihat F-01).
- Mata uang dan ukuran saldo akun demo (memengaruhi lot minimum)?
- ID model OpenAI yang akan dipakai (wajib diisi owner di `.env`; default Claude: `claude-sonnet-5-5`).
