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
- [ ] Kasus gagal: terminal mati/putus -> coba sambung ulang tiap 10 detik (maks 5 kali), status "terputus" di dashboard, tidak ada order dikirim selama terputus.

**F-02 Analisa teknikal & filter berita**
- [ ] Menghitung EMA 20/50/200, RSI 14, ATR 14, MACD, serta level swing high/low terakhir, pada M15 dan H1.
- [ ] Kalender ekonomi high-impact (mata uang terkait simbol; USD untuk XAUUSD) diambil minimal tiap 6 jam dan disimpan.
- [ ] Tidak ada entry baru dari 30 menit sebelum sampai 30 menit sesudah berita high-impact terkait.
- [ ] Kasus gagal: data kalender lebih tua dari 24 jam atau gagal diambil -> entry diblokir (fail-safe), tercatat di `risk_events`.

**F-03 Panel multi-AI & konsensus**
- [ ] Setiap candle M15 yang ditutup, untuk tiap simbol, bot mengirim paket fitur pasar ke Claude dan OpenAI secara paralel.
- [ ] Setiap AI wajib membalas JSON terstruktur: `direction` (buy/sell/hold), `confidence` (0-1), `sl_price`, `tp_price`, `rationale`.
- [ ] Konsensus "eksekusi" hanya jika SEMUA model aktif: arah sama (bukan hold) dan `confidence` >= 0.6.
- [ ] Kasus gagal: satu model timeout (> 30 detik), error, atau JSON tidak valid -> dihitung tidak setuju, hasil `skip`, error tersimpan.
- [ ] Setiap sinyal dan tiap opini AI tersimpan lengkap dengan alasan.

**F-04 Manajemen risiko & kill switch**
- [ ] Lot = (balance x risiko% per trade) / jarak SL, dibulatkan ke `volume_step` broker, dibatasi `volume_min`/`volume_max`.
- [ ] Default: risiko 0.5% per trade, maks rugi harian 2%, maks 2 posisi terbuka total, maks 1 posisi per simbol.
- [ ] SL/TP divalidasi: jarak SL 0.8-3.0 x ATR, rasio reward:risk >= 1.5; di luar itu -> sinyal diblokir.
- [ ] Blokir entry jika spread > batas per simbol, atau di luar sesi trading (default 07:00-20:00 UTC).
- [ ] Jika rugi harian (realized + floating, dari balance awal hari) mencapai batas -> kill switch aktif otomatis: semua posisi ditutup, tidak ada entry baru sampai hari berikutnya (UTC) atau direset manual.
- [ ] Tombol kill switch manual di dashboard menghentikan entry dan menutup semua posisi.

**F-05 Eksekusi order & manajemen posisi**
- [ ] Order market dikirim dengan SL dan TP terpasang sejak awal; magic number khusus bot.
- [ ] Pada +1R, SL digeser ke breakeven; setelah +1.5R, trailing stop berjarak 1 x ATR.
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
- Keamanan & privasi: API key hanya di `.env`; dashboard hanya `127.0.0.1`; aksi ubah/kontrol butuh header token lokal; log tidak memuat API key.
- Keandalan: bot pulih otomatis dari restart (rekonsiliasi posisi) dan dari putus koneksi MT5/internet.
- Platform: Windows 10/11 64-bit, MT5 terpasang, Python 3.11, browser modern (Chrome/Edge) untuk dashboard.
- Aksesibilitas: kontras teks >= 4.5:1, dapat dipakai keyboard.

## 8. Asumsi, Risiko, Dependensi
- [ASUMSI] Broker sudah dipilih dan menyediakan simbol bernama persis `XAUUSD` dan `EURUSD` (jika ada sufiks, diatur di pengaturan).
- [ASUMSI] Pengguna sudah punya akun demo MT5 dan API key Anthropic + OpenAI.
- [ASUMSI] Kalender ekonomi memakai feed JSON gratis (mis. Forex Factory mingguan); jika sumber berubah, diganti tanpa mengubah kontrak internal.
- [ASUMSI] Model dipanggil hanya saat candle M15 ditutup (bukan tiap tick) untuk mengendalikan biaya API; estimasi <= 400 panggilan/hari.
- [ASUMSI] Kill switch harian menutup semua posisi (bukan hanya memblokir entry).
- [ASUMSI] Jika beberapa model memberi SL/TP berbeda: SL dipilih yang terjauh (valid), TP yang terdekat.
- [ASUMSI] Kriteria kelayakan live: >= 30 trade, profit factor >= 1.3, max drawdown <= 10%, 0 pelanggaran batas risiko, >= 4 minggu.
- Risiko: AI keliru atau halusinasi -> mitigasi: konsensus bulat, validasi SL/TP deterministik, batas risiko di luar AI.
- Risiko: kerugian finansial nyata saat live -> mitigasi: demo dulu, penjaga mode live berlapis, kill switch.
- Risiko: tidak ada jaminan profit; hasil demo tidak menjamin hasil live (slippage, spread).
- Dependensi: terminal MT5 + paket Python `MetaTrader5` (hanya Windows), API Anthropic, API OpenAI, feed kalender ekonomi.

## 9. Pertanyaan Terbuka
- Nama broker dan sufiks simbol (mis. `XAUUSDm`)?
- Mata uang dan ukuran saldo akun demo (memengaruhi lot minimum)?
- Model spesifik Claude/OpenAI yang ingin dipakai (default diatur di TRD, dapat diganti di pengaturan)?
