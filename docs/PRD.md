# PRD - TradingBot AI (MT5)

> Versi: 0.5 | Diperbarui: 2026-10-29 | Status: Draft (menunggu persetujuan)

## 1. Ringkasan
Bot trading otomatis untuk Windows yang terhubung ke MetaTrader 5. Beberapa model AI (satu atau lebih model Claude dan satu atau lebih model OpenAI) menganalisa data pasar XAUUSD dan EURUSD, dan order hanya dieksekusi jika **semua** model setuju arah yang sama serta lolos batas risiko. Pengguna memantau dan mengontrol bot lewat dashboard web lokal dan menerima notifikasi kejadian kritis lewat Telegram. Tahap awal: **akun demo saja**.

**Strategi:** diskresi penuh AI (keputusan owner). Tidak ada aturan setup entry di kode; setiap model menilai sendiri paket fitur pasar (TRD 5c). Kode hanya menyaring kondisi (guard dan rem), memvalidasi SL/TP, menghitung lot, dan mengelola posisi dengan aturan tetap. Setiap model belajar dari hasil keputusannya sendiri lewat pelajaran terstruktur yang diterapkan otomatis dengan pengaman (F-08).

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

Definisi:
- R (R-multiple): profit bersih trade / `risk_amount`. Untuk hasil hipotetis (F-08): jarak harga dari entry sampai keluar / jarak entry-SL, bertanda.
- Max drawdown: penurunan terbesar dari puncak ke lembah pada kurva balance (trade tertutup) sejak uji demo dimulai, dalam % dari puncak.
- Pelanggaran batas risiko: tindakan bot yang melanggar aturan (lot melebihi target risiko, posisi melebihi batas, entry saat kill switch/guard aktif). Rugi melebihi SL karena gap pasar atau slippage (risiko yang diterima owner) dicatat sebagai `excess_loss`, bukan pelanggaran.
- Kriteria layak live hanya dinilai jika: `prompt_version` terakhir sudah berlaku >= 2 minggu tanpa perubahan (pelajaran dibekukan), rata-rata R trade nyata pada versi itu >= 0, dan tidak ada perubahan pengaturan risiko di `settings_changes` selama 2 minggu terakhir.

## 4. Pengguna
| Peran | Deskripsi | Kebutuhan utama |
|---|---|---|
| Trader (owner) | Satu orang, menjalankan bot di PC Windows atau VPS Windows sendiri | Bot otomatis, batas risiko ketat, bisa menghentikan kapan saja, melihat alasan tiap keputusan, tahu jika terjadi masalah walau tidak di depan layar |

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
| F-06 | Dashboard web lokal | P0 | Sebagai trader, saya ingin melihat status, sinyal, posisi, alasan bot tidak trading, dan mengubah pengaturan dari browser |
| F-07 | Jurnal & evaluasi performa | P1 | Sebagai trader, saya ingin statistik, ringkasan AI, dan scorecard tiap model, agar bisa menilai kelayakan bot dan mengganti model yang lemah |
| F-08 | Evaluasi & pelajaran AI | P1 | Sebagai trader, saya ingin tiap AI mengevaluasi keputusannya sendiri dan menerapkan pelajaran secara otomatis dengan pengaman, agar kualitas keputusan membaik tanpa menaikkan risiko |
| F-09 | Notifikasi kritis & watchdog | P1 | Sebagai trader, saya ingin menerima pesan Telegram saat terjadi kejadian kritis dan bot dijalankan ulang otomatis jika mati, agar bot aman walau tidak diawasi |
| F-10 | Instalasi otomatis VPS Windows | P0 | Sebagai trader, saya ingin satu skrip memasang semua yang dibutuhkan di VPS Windows baru, agar bot bisa berjalan tanpa setup manual yang panjang |

### Acceptance Criteria
**F-01 Koneksi MT5 & data pasar**
- [ ] Bot terhubung ke terminal MT5 dan login otomatis memakai `MT5_LOGIN`, `MT5_PASSWORD`, `MT5_SERVER` dari `.env` (jika kosong, memakai akun yang sedang login di terminal), lalu membaca saldo, equity, tipe akun (demo/real). Login gagal -> bot menolak start dengan pesan jelas tanpa menampilkan password.
- [ ] Mengambil >= 2000 candle M15 dan >= 1000 candle H1 terakhir per simbol (cukup untuk median ATR 20 hari bursa dan EMA200 yang konvergen).
- [ ] Nama simbol broker fleksibel: tiap simbol kanonik (`XAUUSD`, `EURUSD`) dipetakan ke nama broker lewat `symbol_map` (mis. `XAUUSDm`, `GOLD`). Saat start, bot mencari kandidat di MT5 dan mengusulkan pemetaan; owner mengonfirmasi/mengubahnya di S-04. Bot menolak start jika simbol belum terpetakan.
- [ ] Saat start, bot memeriksa: Algo Trading aktif di terminal, akun bertipe **hedging** (netting ditolak), dan mode pengisian order (`filling_mode`) yang didukung simbol; gagal salah satu -> bot menolak start dengan pesan jelas.
- [ ] Hanya satu instans bot boleh berjalan; instans kedua menolak start dengan pesan jelas.
- [ ] Akun MT5 dipakai khusus untuk bot. Bot hanya mengelola posisi dengan magic number bot; posisi lain (manual) diabaikan dan tidak diambil alih, tetapi tetap terhitung di equity untuk batas rugi harian (konservatif).
- [ ] Kasus gagal: terminal mati/putus -> coba sambung ulang tiap 10 detik (5 kali), lalu tiap 60 detik tanpa batas; status "terputus" di dashboard; tidak ada order dikirim selama terputus; otomatis lanjut saat tersambung kembali (posisi tetap terlindungi SL/TP di server broker).

**F-02 Analisa teknikal & filter berita**
- [ ] Menghitung paket fitur sesuai skema `f1` (TRD 5c): EMA 20/50/200, RSI 14, ATR 14, MACD, swing high/low (fractal 5-bar), pada M15 dan H1, hanya dari candle yang sudah tutup.
- [ ] Kalender ekonomi high-impact (mata uang terkait simbol; USD untuk XAUUSD) diambil minimal tiap 6 jam dan disimpan. Sumber lewat `NewsProvider` yang dapat diganti (default: feed JSON Forex Factory mingguan yang tidak resmi); owner juga bisa menambah jendela blokir manual (`manual_blackouts`) untuk berita penting.
- [ ] Tidak ada entry baru dari `news_block_minutes` (default 30) menit sebelum sampai sesudah berita high-impact terkait.
- [ ] Kasus gagal: data kalender lebih tua dari 24 jam, gagal diambil, atau tidak mencakup rentang `now ± news_block_minutes` (mis. di pergantian minggu) -> entry diblokir (`calendar_stale`), tercatat di `risk_events` saat kondisi mulai.

**F-03 Panel multi-AI & konsensus**
- [ ] Setiap candle M15 yang ditutup, untuk tiap simbol yang lolos guard F-04, bot mengirim paket fitur `f1` (termasuk batas `sl_atr_min`/`sl_atr_max` dan `min_rr`) ke semua model aktif secara paralel.
- [ ] Setiap AI wajib membalas JSON terstruktur: `direction` (buy/sell/hold), `confidence` (0-1), `sl_price`, `tp_price`, `rationale`. `sl_price`/`tp_price` wajib untuk buy/sell dan boleh kosong untuk hold. SL/TP di sisi yang salah (mis. SL di atas harga untuk buy) -> opini tidak valid (dihitung tidak setuju).
- [ ] Claude dan OpenAI sama-sama didukung. Daftar model diatur di `ai_models` (penyedia, ID model, aktif/nonaktif), boleh lebih dari satu model per penyedia. Total model aktif maks `max_ai_models` (default 4). Jika `require_provider_diversity` = 1 (default), minimal satu model aktif dari tiap penyedia (Claude dan OpenAI), agar konsensus tidak hanya dari satu keluarga model. Penyedia baru bisa ditambahkan tanpa mengubah logika konsensus.
- [ ] Konsensus "eksekusi" hanya jika SEMUA model aktif: arah sama (bukan hold) dan `confidence` >= `min_confidence` (default 0.6), dengan jumlah model aktif >= `min_ai_models` (minimal 2, tidak bisa diturunkan, dan tidak boleh melebihi jumlah model aktif).
- [ ] Setiap panggilan AI memakai temperature rendah yang tetap dan mencatat `prompt_version` serta `feature_schema`, agar keputusan dapat diaudit.
- [ ] Pelajaran aktif milik tiap model (F-08) disisipkan ke prompt model itu saja, dan efeknya diterapkan kode pada opini model itu sebelum konsensus.
- [ ] Pelacakan biaya: setiap panggilan AI (keputusan, refleksi, penentang, jurnal, uji kesehatan) dicatat di `ai_calls` beserta token; perkiraan biaya dihitung dari `ai_price_table` (diisi owner, opsional). Jika panggilan hari ini mencapai `max_ai_calls_per_day` (600) -> entry diblokir sampai 00:00 UTC (`ai_budget`); refleksi dan penentang ditunda.
- [ ] Kesehatan AI: `ai_error_alert_count` (3) error beruntun dari satu model, atau error autentikasi/model tidak ditemukan -> model ditandai tidak sehat; sinyal berikutnya diblokir (`ai_unhealthy`) tanpa memanggil model lain; model itu diuji ulang tiap 4 candle dan pulih setelah satu panggilan sukses; banner di S-01 dan notifikasi F-09. Owner bisa menonaktifkan model itu di S-04 untuk melanjutkan dengan model lain (tetap tunduk `min_ai_models` dan diversitas).
- [ ] Kasus gagal: satu model timeout (> 30 detik), error, atau JSON tidak valid -> dihitung tidak setuju, hasil `skip`, error tersimpan.
- [ ] Setiap sinyal dan tiap opini AI tersimpan lengkap dengan alasan.

**F-04 Manajemen risiko & kill switch**
- [ ] Lot = uang risiko / ((jarak SL / `tick_size`) x `tick_value_loss` + 2 x `commission_per_lot`), dengan uang risiko = balance x `risk_per_trade_pct`. Selalu **dibulatkan ke bawah** ke `volume_step`, dibatasi `volume_max`; jika < `volume_min` -> diblokir (`lot_too_small`), tidak pernah dinaikkan.
- [ ] Default: risiko 0.5% per trade, maks rugi harian 2%, maks 2 posisi terbuka total, maks 1 posisi per simbol (dikunci).
- [ ] Pengaturan ditolak jika `risk_per_trade_pct` x `max_open_positions` > `max_daily_loss_pct` (risiko terbuka tidak boleh melebihi batas harian).
- [ ] SL/TP divalidasi: jarak SL `sl_atr_min`-`sl_atr_max` x ATR (default 0.8-3.0), rasio reward:risk >= `min_rr` (default 1.5); di luar itu -> sinyal diblokir (`invalid_sltp`).
- [ ] Blokir entry jika spread > `max_spread_atr_ratio` (0.10) x ATR M15, di luar sesi trading (default 07:00-20:00 UTC), atau pasar simbol sedang tutup/libur (`market_closed`).
- [ ] Margin: sebelum order, `order_check` broker memastikan margin cukup dan margin level setelah order >= `min_margin_level_pct` (300%); jika tidak -> diblokir (`insufficient_margin`).
- [ ] Kunci eksekusi: hanya satu order diproses pada satu waktu. Di dalam kunci, semua guard (posisi, entry harian, rem, kill switch) dan validasi spread, SL/TP, lot, serta margin diulang dengan bid/ask terbaru tepat sebelum order dikirim (dan sebelum retry); tidak valid -> diblokir dengan alasannya.
- [ ] Rem tambahan (semua oleh kode, nilai di `settings`):
  - Setelah `max_consecutive_losses` (3) kekalahan beruntun -> entry dijeda `loss_pause_hours` (4) jam (`consecutive_losses`). Kalah = trade dengan profit bersih < 0; trade dengan profit >= 0 me-reset hitungan.
  - Maks `max_entries_per_day` (4) entry terisi per hari UTC untuk semua simbol (`max_entries_day`).
  - Rugi mingguan = (baseline Senin 00:00 UTC - equity sekarang) / baseline; mencapai `max_weekly_loss_pct` (4%) -> tidak ada entry baru sampai Senin berikutnya (`weekly_loss_limit`); posisi terbuka tidak ditutup paksa.
  - ATR M15 > `volatility_atr_multiple` (3) x median ATR M15 20 hari bursa -> entry diblokir (`volatility_shock`).
  - Tidak ada entry baru setelah Jumat `friday_cutoff_utc` (18:00 UTC) sampai pasar buka kembali (`friday_cutoff`); posisi terbuka tetap dibiarkan dengan SL.
- [ ] Tahan restart: semua baseline dan penghitung rem dihitung dari riwayat deal MT5 dan database, bukan memori. `start_balance` = balance sekarang - profit bersih trading (tanpa deposit/penarikan) sejak 00:00 UTC; baseline mingguan sama, sejak Senin 00:00 UTC. Restart tidak me-reset rem.
- [ ] Rugi harian = (`start_balance` - equity sekarang) / `start_balance` (mencakup realized hari ini + floating semua posisi). Jika rugi harian mencapai batas -> kill switch aktif otomatis: tidak ada entry baru sampai hari berikutnya (UTC) atau direset manual. Perlakuan posisi terbuka diatur `kill_switch_mode`:
  - `protect_winners` (default): posisi rugi ditutup; posisi yang sedang untung tidak ditutup paksa, SL-nya dikunci minimal breakeven + buffer, trailing tetap berjalan sampai kena SL/TP. Jika SL tersebut tidak bisa dipasang secara valid (di atas bid untuk BUY / di bawah ask untuk SELL, atau melanggar `stops_level`/`freeze_level`), posisi ditutup.
  - `close_all`: semua posisi ditutup segera.
- [ ] Tombol kill switch manual di dashboard memakai `kill_switch_mode` yang sama; tersedia juga tombol terpisah "Tutup semua sekarang" (panic) yang selalu menutup semua posisi.

**F-05 Eksekusi order & manajemen posisi**
- [ ] Order market dikirim dengan SL dan TP terpasang sejak awal, magic number bot, comment `tb:<signal_id>`, dan `deviation` = `max_slippage_atr_ratio` (0.10) x ATR M15 (dalam points).
- [ ] Setelah fill, `risk_amount` dihitung ulang dari harga fill; jika > 110% risiko rencana (`planned_risk_amount`) -> `excess_risk` dicatat dan dinotifikasi (posisi tetap dengan SL).
- [ ] Pada +1R, SL digeser ke breakeven + buffer. Buffer = komisi pulang-pergi (2 x `commission_per_lot`, dikonversi ke jarak harga) + `breakeven_buffer_points` (cadangan slippage/swap). Spread tidak dimasukkan karena sudah terbayar saat entry (BUY masuk di ask, SL-nya terpicu di bid); setelah +1.5R, trailing stop berjarak 1 x ATR. SL hanya bergerak ke arah menguntungkan, dan hanya digeser jika perbaikannya >= `trailing_min_step_atr` (0.1) x ATR. Setiap modifikasi SL wajib menghormati `stops_level`/`freeze_level` broker.
- [ ] Posisi dibiarkan terbuka melewati rollover dan akhir pekan, hanya dilindungi SL/TP (keputusan owner; lihat Risiko).
- [ ] Status posisi di database selalu sinkron dengan MT5 (rekonsiliasi tiap siklus dan saat startup).
- [ ] Trade tertutup dengan rugi > 110% `risk_amount` (gap/slippage) -> `excess_loss` dicatat dan dinotifikasi.
- [ ] Kasus gagal: order ditolak, requote, atau hasil tidak pasti (koneksi putus saat kirim) -> sebelum retry, cek posisi/deal berdasarkan magic, simbol, waktu sejak sinyal, dan comment; jika ternyata sudah terisi -> diambil alih, tidak dikirim ulang; jika belum -> maks 1 retry setelah validasi ulang; tetap gagal -> `rejected`, tidak diulang pada candle yang sama.
- [ ] Mode `live` hanya jalan jika semua penjaga lolos (lihat TRD bagian 5); default dan paksa `demo`.

**F-06 Dashboard web lokal**
- [ ] Menampilkan: status bot, mode, koneksi MT5, saldo/equity, P/L hari ini, posisi terbuka, sinyal terakhir + opini tiap AI, kesehatan tiap model AI, jumlah panggilan dan perkiraan biaya AI hari ini.
- [ ] Panel "Kenapa bot tidak trading" di S-01: semua blokir yang sedang aktif beserta alasan dan waktu berakhirnya (mis. "Jeda kalah beruntun sampai 14:20", "Cutoff Jumat", "Model OpenAI tidak sehat").
- [ ] Bisa mengubah parameter risiko, rem, pemetaan simbol, daftar model AI, dan pengaturan pelajaran; perubahan tersimpan, tercatat di `settings_changes`, terlihat di S-04, dan berlaku pada siklus berikutnya.
- [ ] Tombol kill switch, reset, dan "Tutup semua sekarang".
- [ ] Waktu ditampilkan dalam zona waktu lokal browser, dengan UTC di tooltip.
- [ ] Tidak ada entry selama `starvation_days` (5) hari bursa -> banner peringatan (dan notifikasi F-09).
- [ ] Kasus gagal: backend mati -> banner "Bot tidak terjangkau"; heartbeat bot > 2 menit -> banner "Bot tidak merespons".

**F-07 Jurnal & evaluasi performa**
- [ ] Statistik harian/mingguan: jumlah trade, win rate, profit factor, rata-rata R, net profit, max drawdown.
- [ ] Ringkasan teks dari AI per periode (hanya dari statistik, terpisah dari keputusan trading), tersimpan.
- [ ] Menampilkan status terhadap kriteria kelayakan live (bagian 3).
- [ ] Scorecard per model dari hasil hipotetis (F-08): jumlah opini buy/sell, win rate, rata-rata R, dan kalibrasi confidence (win rate per rentang 0.6-0.7, 0.7-0.8, 0.8-0.9, 0.9-1.0), agar owner bisa menilai dan mengganti model yang lemah.

**F-08 Evaluasi & pelajaran AI (otomatis)**
- [ ] Hasil hipotetis: untuk setiap opini buy/sell (arah asli sebelum efek pelajaran) dan setiap sinyal yang dibatalkan pelajaran, kode mencatat hasil hipotetis dari candle M15 berikutnya: mana yang tersentuh duluan, SL atau TP; jika keduanya tersentuh di candle yang sama dianggap SL; tanpa trailing dan biaya; setelah `paper_horizon_candles` (96) candle ditutup di close candle terakhir. Tanpa order dan tanpa panggilan AI tambahan. Hanya untuk perbandingan relatif, bukan laporan performa.
- [ ] Refleksi: setiap trade tertutup yang punya sinyal asal, tiap model yang ikut memutuskan menulis evaluasi singkat atas keputusannya sendiri (alasan entry vs hasil), tersimpan di `ai_reflections`. Posisi yang diambil alih tanpa sinyal asal tidak direfleksikan.
- [ ] Usulan pelajaran: dalam panggilan refleksi yang sama, model boleh mengusulkan pelajaran terstruktur: kondisi atas kunci fitur skalar skema `f1` (mis. `rsi14_m15 > 70`, arah buy, XAUUSD) + efek `avoid` (opini model itu menjadi hold saat kondisi cocok) atau `raise_confidence` (butuh confidence >= nilai tertentu saat kondisi cocok). Pelajaran hanya boleh memperketat; usulan yang melonggarkan ditolak kode.
- [ ] Teks pelajaran yang masuk prompt dibuat kode dari data terstruktur memakai template, bukan ditulis AI. Teks bebas keluaran AI (rationale, refleksi, catatan penentang) tidak pernah dimasukkan ke prompt mana pun.
- [ ] Duplikat & cooldown: usulan identik (penyedia, model, simbol, arah, kondisi, efek sama) digabung; usulan yang sama dengan pelajaran berstatus `rejected`, `disabled`, `expired`, atau `rolled_back` dalam `lesson_cooldown_weeks` (4) minggu terakhir ditolak otomatis.
- [ ] Verifikasi kode: memakai hasil hipotetis opini model pemilik (bukan trade nyata) yang cocok dengan kondisi. Usulan menjadi `pending` hanya jika >= `lesson_min_samples` (20) sampel, rata-rata R < 0, dan lebih buruk dari rata-rata R semua opini model itu pada arah yang sama. Arah asli tetap dicatat setelah pelajaran aktif, sehingga bukti terus bertambah.
- [ ] Pelajaran per model: hanya berlaku untuk model pengusulnya; maks `lesson_max_active` (10) aktif per model dan `lesson_max_active_total` (15) aktif untuk semua model; jika penuh, yang buktinya paling lemah tidak diaktifkan. Catatan: karena konsensus harus bulat, pelajaran satu model membatalkan keputusan seluruh panel; batas total mencegah bot berhenti trading karena terlalu banyak filter. Pelajaran terikat ke ID model; mengganti ID model berarti mulai tanpa pelajaran.
- [ ] Penentang mingguan: setiap `lesson_review_utc` (Sabtu 00:00 UTC, pasar tutup), model dari penyedia lain (Claude memeriksa pelajaran model OpenAI dan sebaliknya) menilai pelajaran pending dan aktif: mencari bukti tandingan, overfitting, sampel kecil. Penentang hanya bisa menolak pending atau menonaktifkan aktif; tidak bisa menambah atau melonggarkan.
- [ ] Verifikasi ulang mingguan: pelajaran aktif yang tidak lagi lolos verifikasi dengan bukti terbaru, atau sudah lewat `lesson_expiry_weeks` (4) minggu, menjadi `expired`.
- [ ] Penerapan otomatis (tanpa persetujuan owner, keputusan owner): pelajaran yang lolos aktif mulai Senin; setiap perubahan set pelajaran membuat `prompt_version` baru, paling banyak sekali seminggu.
- [ ] Rollback otomatis, hanya di job mingguan: jika versi aktif sudah punya >= `rollback_min_trades` (15) trade nyata (tanpa yang ditutup kill switch, manual, atau `unknown`) dan rata-rata R-nya lebih buruk dari versi sebelumnya -> baris versi sebelumnya diaktifkan kembali; pelajaran yang baru di versi buruk menjadi `rolled_back`; minggu itu tidak ada aktivasi baru.
- [ ] S-05 menampilkan untuk tiap pelajaran: berapa sinyal yang dibatalkannya dan hasil hipotetis sinyal-sinyal itu.
- [ ] Owner bisa mematikan semua pelajaran (`lessons_enabled` = 0) di S-04; bot langsung memakai prompt dasar.
- [ ] Pembekuan: jika `lessons_frozen` = 1, verifikasi ulang, rollback, penentang, dan aktivasi hanya mencatat, tidak mengubah set pelajaran. Wajib aktif minimal 2 minggu terakhir uji demo.
- [ ] Kasus gagal: penentang error/timeout atau tidak ada model aktif dari penyedia lain -> pelajaran pending tidak diaktifkan, set aktif tetap; refleksi gagal -> dicatat, trade tetap tersimpan; anggaran AI tercapai -> refleksi dan penentang ditunda.

**F-09 Notifikasi kritis & watchdog**
- [ ] Pesan Telegram satu arah (bot -> owner) untuk: kill switch aktif (otomatis/manual) dan reset, batas rugi mingguan tercapai, jeda kalah beruntun dimulai, model AI tidak sehat, batas panggilan AI tercapai, `excess_loss`/`excess_risk`, `insufficient_margin`, MT5 terputus > 5 menit dan tersambung kembali, bot start/restart/crash, dan tidak ada entry selama `starvation_days`.
- [ ] Isi pesan: jenis kejadian, simbol (jika ada), angka kunci dalam % (tanpa saldo nominal), dan waktu UTC; tanpa API key/token.
- [ ] Anti-spam: jenis kejadian yang sama maks 1 pesan per `notify_cooldown_minutes` (30); yang ditahan dicatat `suppressed`.
- [ ] Telegram tidak menerima perintah; kontrol tetap hanya dari dashboard lokal.
- [ ] `TELEGRAM_BOT_TOKEN` dan `TELEGRAM_CHAT_ID` di `.env`; kosong -> notifikasi nonaktif tanpa mengganggu bot; tombol "Kirim tes" di S-04.
- [ ] Watchdog: proses terpisah menjalankan bot, menjalankan ulang jika bot keluar/crash atau heartbeat tidak diperbarui > 2 menit (maks 5 kali per jam, lalu berhenti dan memberi notifikasi "bot mati, butuh tindakan"), dan mengirim notifikasi setiap restart.
- [ ] Kasus gagal: kirim gagal -> retry 3 kali dengan jeda, lalu dicatat `failed`; status terakhir terlihat di S-01; notifikasi tidak pernah menghambat trading.

**F-10 Instalasi otomatis VPS Windows**
- [ ] Satu skrip PowerShell (`scripts/setup_vps.ps1`), dijalankan sekali sebagai Administrator di VPS Windows baru (Windows Server 2022/2025 atau Windows 10/11 64-bit), memasang Python 3.14, Git, dan terminal MT5 tanpa interaksi installer; tanda tangan digital tiap installer diverifikasi sebelum dijalankan.
- [ ] Skrip meng-clone repo (publik tanpa token; privat dengan token GitHub read-only yang ditanyakan secara tersembunyi dan disimpan di Windows Credential Manager, bukan di file atau URL), membuat virtualenv, dan memasang dependensi.
- [ ] Skrip membuat `.env` dari `.env.example`: secret ditanyakan dengan input tersembunyi, `DASHBOARD_TOKEN` dibuat acak, `MT5_PATH` diisi otomatis, `LIVE_ENABLED` selalu `false`, dan akses file `.env` dibatasi ke user bot.
- [ ] Skrip mengatur Windows untuk uptime (matikan sleep/hibernate, cegah restart otomatis Windows Update saat user login, jam aktif mencakup sesi trading) dan mendaftarkan Task Scheduler: MT5 dan bot (lewat `start.bat`) berjalan otomatis saat user login, tanpa hak admin.
- [ ] Aman dijalankan ulang: komponen yang sudah ada dilewati, repo diperbarui (`git pull`), dependensi diperbarui, `.env` yang sudah ada tidak ditimpa kecuali diminta. Menjalankan ulang skrip juga menjadi cara update bot.
- [ ] Di akhir, skrip menjalankan cek otomatis (Python 3.14 di virtualenv, `pip check`, `python -m tradingbot --version`, tes, MT5 terpasang, kelengkapan `.env`, `LIVE_ENABLED=false`, task terdaftar) dan menampilkan ringkasan lolos/peringatan/gagal; log setup tidak memuat secret.
- [ ] Langkah yang tetap manual ditampilkan di akhir: memilih broker dan akun demo, memastikan tombol Algo Trading di MT5 aktif, auto-logon (opsional, lewat Sysinternals Autologon), dan memutus RDP dengan "Disconnect" (bukan "Sign out").

## 6. Di Luar Scope (jangan dikerjakan)
- Pasar selain forex/emas di MT5 (kripto, saham), instrumen selain XAUUSD dan EURUSD.
- Backtesting engine, optimasi parameter otomatis, machine learning/fine-tuning/training model sendiri. Pelajaran tertulis di prompt dan hasil hipotetis sinyal (F-08) bukan backtesting/training dan termasuk scope.
- Aturan setup entry berbasis kode (strategi = diskresi penuh AI, keputusan owner).
- Pelajaran AI yang mengubah batas risiko, lot, SL/TP, kill switch, atau rem tambahan.
- Pending order (limit/stop), membuka posisi berlawanan pada simbol yang sama (strategi hedging; berbeda dengan tipe akun hedging yang diwajibkan F-01), grid, martingale, averaging down.
- Multi-akun, multi-user, login, akses dashboard dari jaringan/internet.
- Notifikasi email/push, perintah atau kontrol bot lewat Telegram (Telegram hanya satu arah, F-09), aplikasi mobile.
- Eksekusi di akun live selama kriteria demo belum terpenuhi dan belum disetujui eksplisit oleh owner.
- AI mengelola posisi setelah entry (manajemen posisi memakai aturan tetap F-05).

## 7. Kebutuhan Non-Fungsional
- Performa: siklus keputusan (data -> AI -> order) <= 60 detik setelah candle M15 ditutup; dashboard termuat < 2 detik.
- Keamanan & privasi: API key, password MT5, token dashboard, dan token Telegram hanya di `.env` (akses file dibatasi ke user bot); dashboard hanya `127.0.0.1` pada `DASHBOARD_PORT` (default 8000) dan menolak header `Host` selain `127.0.0.1:<port>`/`localhost:<port>` (anti DNS rebinding); aksi ubah/kontrol butuh header token lokal; log dan pesan Telegram tidak memuat secret; koneksi keluar hanya ke API Anthropic, OpenAI, Telegram, dan feed kalender.
- Keandalan: bot pulih otomatis dari restart (rekonsiliasi posisi, rem dari riwayat deal), dari putus koneksi MT5/internet, dan dari crash (watchdog F-09).
- Platform: VPS Windows (disarankan untuk uptime 24/5; Windows Server 2022/2025) atau PC Windows 10/11, 64-bit, dipasang dengan F-10; MT5; Python 3.14; browser modern (Chrome/Edge) untuk dashboard.
- Aksesibilitas: kontras teks >= 4.5:1, dapat dipakai keyboard.

## 8. Asumsi, Risiko, Dependensi
- [ASUMSI] Broker menyediakan emas dan EURUSD dengan nama apa pun; pemetaan lewat `symbol_map` (F-01).
- [ASUMSI] Pengguna sudah punya akun demo MT5, API key Anthropic + OpenAI, dan bot Telegram (token + chat ID).
- Akun MT5 khusus bot (keputusan owner); trade manual tidak dilakukan di akun yang sama.
- Bot berjalan di VPS Windows yang diakses lewat RDP (keputusan owner). Repo GitHub saat ini publik dan akan dijadikan privat; F-10 mendukung keduanya.
- [ASUMSI] Spesifikasi VPS minimal 2 vCPU, 4 GB RAM, 40 GB disk.
- Saldo akun demo disamakan dengan rencana modal live, agar ukuran lot dan hasil uji realistis.
- Kalender ekonomi: default feed JSON mingguan Forex Factory (`nfs.faireconomy.media`), gratis tetapi **tidak resmi**, tanpa jaminan layanan, hanya minggu berjalan. Bisa mati/berubah tanpa pemberitahuan; karena itu ada fail-safe, provider yang dapat diganti, dan jendela blokir manual. Belum diverifikasi dari lingkungan pengembangan ini (jaringan diblokir); diuji di langkah 7.
- [ASUMSI] Model dipanggil hanya saat candle M15 ditutup (bukan tiap tick) untuk mengendalikan biaya API; estimasi ~210 panggilan keputusan/hari dengan 2 model (2 simbol x ~52 candle dalam sesi 07:00-20:00 UTC x 2 model), naik sebanding jumlah model aktif (4 model -> ~420), lebih sedikit karena guard memblokir sebelum AI dipanggil. F-08 menambah 1 refleksi per model per trade tertutup + 2-4 panggilan penentang per minggu. Semua dibatasi `max_ai_calls_per_day`.
- Kill switch: lihat F-04 (`protect_winners` default, `close_all` opsional).
- [ASUMSI] Jika beberapa model memberi SL/TP berbeda: SL dipilih yang terjauh (valid), TP yang terdekat.
- [ASUMSI] Kriteria kelayakan live: >= 30 trade, profit factor >= 1.3, max drawdown <= 10%, 0 pelanggaran batas risiko, >= 4 minggu, ditambah syarat versi stabil di bagian 3.
- Risiko: AI keliru atau halusinasi -> mitigasi: konsensus bulat, validasi SL/TP deterministik, batas risiko di luar AI.
- Risiko: kerugian finansial nyata saat live -> mitigasi: demo dulu, penjaga mode live berlapis, kill switch.
- Risiko: tidak ada jaminan profit; hasil demo tidak menjamin hasil live (slippage, spread).
- Risiko (diterima owner): posisi dibiarkan melewati rollover (~21:00-22:00 UTC, spread melebar) dan akhir pekan; gap harga saat pasar buka dapat melewati SL sehingga rugi per trade > `risk_per_trade_pct` dan rugi harian > batas. Mitigasi: risiko kecil per trade, maks 2 posisi, `excess_loss` dicatat.
- Risiko (diterima owner, hanya dicatat): XAUUSD dan EURUSD sama-sama berlawanan dengan USD; dua posisi searah terhadap USD ~ menggandakan eksposur USD (maks 1% total pada default).
- Catatan kriteria live: >= 30 trade dengan profit factor >= 1.3 adalah gerbang minimum, bukan bukti statistik bahwa strategi menguntungkan; dengan filter konsensus bulat, 30 trade bisa butuh > 4 minggu.
- Risiko (diterima owner): strategi diskresi penuh AI tanpa aturan setup sulit dievaluasi; alasan keputusan bisa berubah antar-candle. Mitigasi: konsensus, rationale tersimpan, rem tambahan F-04, scorecard F-07.
- Risiko (diterima owner): pelajaran otomatis bisa overfitting pada sampel kecil. Mitigasi F-08: hanya memperketat, teks dari template, verifikasi kode >= 20 sampel, per model, batas total, cooldown, kedaluwarsa, penentang mingguan, rollback, pembekuan.
- Risiko: hasil hipotetis tanpa biaya dan trailing cenderung lebih optimistis dari hasil nyata; hanya dipakai untuk perbandingan relatif.
- Risiko: beberapa model dari penyedia yang sama cenderung berpendapat mirip. Mitigasi: `require_provider_diversity`.
- Risiko: PC pribadi bisa sleep, restart karena Windows Update, atau mati listrik. Mitigasi: watchdog, Task Scheduler, checklist README, opsi VPS.
- Risiko: password akun MT5 tersimpan di `.env` VPS (login otomatis, keputusan owner). Mitigasi: hanya di `.env` dengan akses dibatasi ke user bot, akun demo dulu, tidak pernah ditulis ke log, database, atau Telegram.
- Risiko: URL atau opsi installer pihak ketiga (Python, Git, MT5) berubah. Mitigasi: URL dapat diganti lewat parameter skrip, tanda tangan digital diverifikasi, diuji di VPS (langkah 1a).
- Risiko: notifikasi Telegram tidak terkirim. Mitigasi: retry, status di dashboard; trading tidak bergantung pada notifikasi.
- Dependensi: terminal MT5 + paket Python `MetaTrader5` (hanya Windows), API Anthropic, API OpenAI, Telegram Bot API, feed kalender ekonomi.

## 9. Pertanyaan Terbuka
- Nama broker (pemetaan simbol diatur fleksibel, lihat F-01).
- Mata uang dan ukuran saldo akun demo (disamakan dengan rencana modal live; memengaruhi lot minimum)?
- ID model OpenAI yang akan dipakai (wajib diisi owner di `.env`; default Claude: `claude-sonnet-5-5`).
- Harga per token tiap model untuk `ai_price_table` (opsional; tanpa ini hanya jumlah token yang ditampilkan).
- Penyedia VPS Windows yang dipakai?
