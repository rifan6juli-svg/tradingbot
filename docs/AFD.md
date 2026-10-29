# AFD - TradingBot AI (MT5)

> Versi: 0.1 | Diperbarui: 2026-10-29 | Merujuk: PRD.md (ID fitur F-xx)

## 1. Peta Layar
| ID | Layar | Rute/URL | Akses | Fitur terkait |
|---|---|---|---|---|
| S-01 | Dashboard | `/` | Owner (localhost) | F-01, F-04, F-05, F-06 |
| S-02 | Sinyal & Opini AI | `/signals` | Owner | F-02, F-03, F-06 |
| S-03 | Posisi & Riwayat | `/trades` | Owner | F-05, F-06 |
| S-04 | Risiko & Pengaturan | `/settings` | Owner | F-04, F-06, F-08 |
| S-05 | Jurnal & Performa | `/journal` | Owner | F-07, F-06, F-08 |

## 2. Navigasi Utama
Bilah navigasi tetap di atas semua layar: Dashboard, Sinyal, Trade, Pengaturan, Jurnal. Kill switch selalu terlihat di header.
```mermaid
flowchart TD
  S01[S-01 Dashboard] --> S02[S-02 Sinyal]
  S01 --> S03[S-03 Trade]
  S01 --> S04[S-04 Pengaturan]
  S01 --> S05[S-05 Jurnal]
  S02 -->|klik trade terkait| S03
  S03 -->|klik sinyal asal| S02
```

## 3. Alur Utama Bot (latar belakang)
```mermaid
flowchart TD
  A[Candle M15 tutup] --> B{MT5 terhubung?}
  B -- Tidak --> X1[Lewati, status terputus]
  B -- Ya --> C[Hitung fitur M15+H1]
  C --> D{Guard: kill switch, sesi, pasar tutup, cutoff Jumat, spread, volatilitas, berita/kalender, posisi penuh, entry harian, kalah beruntun, rugi mingguan, model AI kurang?}
  D -- Blokir --> X2[Simpan signal decision=blocked + risk_event]
  D -- Lolos --> E[Tanya semua model aktif paralel, terapkan efek pelajaran per model]
  E --> F{Semua model aktif buy atau semua sell, conf >= min_confidence, SL/TP di sisi benar?}
  F -- Tidak --> X3[Simpan signal decision=skip]
  F -- Ya --> G[Gabungkan SL/TP, validasi ATR + RR]
  G -- Tidak valid --> X2
  G -- Valid --> H[Hitung lot, validasi ulang harga+spread, kirim order dengan SL/TP]
  H -- Gagal --> X4[trade status=rejected]
  H -- Sukses --> I[trade status=open, kelola breakeven/trailing]
```

## 4. Alur per Fitur

### F-01 Koneksi MT5 & data pasar
**Pemicu:** bot start, atau tiap siklus.
**Alur utama:**
1. Bot memanggil `initialize` ke terminal MT5 dan membaca info akun.
2. Bot membandingkan tipe akun dengan `settings.mode` (penjaga live, TRD 5).
3. Tiap siklus mengambil >= 300 candle M15 dan H1 per simbol; S-01 menampilkan status "terhubung", saldo, equity.

**Alur alternatif / gagal:**
- Terminal tidak berjalan -> status "terputus" (S-01), coba lagi tiap 10 detik (5 kali) lalu tiap 60 detik tanpa batas, catat `risk_events` (`broker_error`); trading lanjut otomatis saat tersambung.
- Algo Trading nonaktif, akun netting, atau `filling_mode` tidak didukung -> bot menolak start dengan pesan penyebab.
- Simbol belum terpetakan / tidak ditemukan -> bot menolak start; S-04 menampilkan kandidat dari MT5 (mis. `XAUUSDm`, `GOLD`) untuk dipilih dan disimpan ke `symbol_map`.
- Tipe akun tidak cocok dengan mode -> bot berhenti (`live_guard`).
- Ada posisi tanpa magic number bot (mis. trade manual) -> diabaikan, tidak diambil alih; tetap terhitung di equity.

### F-02 Analisa teknikal & filter berita
**Pemicu:** setiap candle M15 tutup; pembaruan kalender tiap 6 jam.
**Alur utama:**
1. Hitung EMA 20/50/200, RSI 14, ATR 14, MACD, swing high/low untuk M15 dan H1.
2. Cek tabel `news_events` dan `manual_blackouts`: ada event `impact = high` mata uang terkait dalam `± news_block_minutes`?
3. Hasil fitur dimasukkan ke paket untuk AI; kalau ada berita -> sinyal `blocked` (`news_block`).

**Alur alternatif / gagal:**
- Kalender gagal diambil / lebih tua dari 24 jam / tidak mencakup waktu sekarang -> blokir entry, `risk_events` (`news_block`, detail "kalender usang").
- Data candle kurang dari 300 -> lewati siklus simbol itu.

### F-03 Panel multi-AI & konsensus
**Pemicu:** fitur lolos guard pada candle M15 tutup.
**Alur utama:**
1. Kirim paket fitur (termasuk batas ATR/RR) ke semua model aktif di `ai_models` secara paralel, dengan prompt dan skema yang sama.
2. Validasi tiap balasan terhadap skema; simpan ke `ai_opinions`.
3. Konsensus: semua `direction` sama dan bukan `hold` dan `confidence >= min_confidence` -> `signals.consensus` = buy/sell; selain itu `none`. `prompt_version` disimpan di sinyal.
4. Tampil di S-02 dengan alasan tiap AI.

**Alur alternatif / gagal:**
- Timeout 30 detik / error API / JSON tidak valid / SL-TP di sisi salah -> opini ditandai error, dihitung tidak setuju, sinyal `skip`.
- Salah satu penyedia dinonaktifkan di S-04 -> konsensus hanya dari model aktif; jumlah model aktif harus >= `min_ai_models` (minimal 2), jika kurang AI tidak dipanggil, sinyal `blocked` (`insufficient_ai_models`).
- `require_provider_diversity` = 1 dan tidak ada model aktif dari salah satu penyedia -> `blocked` (`insufficient_ai_models`).

### F-04 Manajemen risiko & kill switch
**Pemicu:** konsensus buy/sell; juga dicek tiap 10 detik untuk batas harian.
**Alur utama:**
1. Gabungkan SL (terjauh valid) dan TP (terdekat) dari semua AI.
2. Validasi jarak SL `sl_atr_min`-`sl_atr_max` x ATR dan reward:risk >= `min_rr`.
3. Hitung lot (rumus PRD F-04), bulatkan ke bawah ke `volume_step`.
3a. Tepat sebelum kirim order (dan sebelum retry): ulangi cek spread dan validasi 2-3 dengan bid/ask terbaru.
4. Pantau rugi harian (rumus PRD F-04); jika mencapai batas -> kill switch ON (blokir entry), perlakukan posisi sesuai `kill_switch_mode` (default `protect_winners`: tutup yang rugi, kunci breakeven + buffer pada yang untung dan biarkan berjalan, tutup jika SL itu tidak bisa dipasang valid; `close_all`: tutup semua), catat `risk_events`.

**Alur alternatif / gagal:**
- SL/TP tidak valid -> `blocked` (`invalid_sltp`).
- Lot hasil hitung < `volume_min` -> `blocked` (`lot_too_small`, risiko terlalu kecil untuk saldo).
- Maks posisi / spread / sesi / kill switch aktif / rem tambahan (kalah beruntun, entry harian, rugi mingguan, volatilitas, cutoff Jumat) -> `blocked` dengan alasan masing-masing.
- Kill switch manual: owner klik tombol (S-01/S-04) -> konfirmasi -> perlakuan posisi sesuai `kill_switch_mode`, status "KILL SWITCH ON". Tombol terpisah "Tutup semua sekarang" selalu menutup semua posisi.
- Reset kill switch: tombol Reset (S-04) dengan konfirmasi; otomatis juga reset pada hari UTC berikutnya untuk pemicu batas harian.

### F-05 Eksekusi order & manajemen posisi
**Pemicu:** sinyal lolos validasi risiko; loop posisi tiap 10 detik.
**Alur utama:**
1. Kirim order market dengan SL, TP, magic number bot; simpan `trades` (`status = open`).
2. Loop posisi: pada +1R geser SL ke breakeven + buffer; setelah +1.5R trailing 1 x ATR; SL tidak pernah mundur; tiap modifikasi mengecek `stops_level`/`freeze_level`.
3. Rekonsiliasi: posisi yang sudah tertutup di MT5 diperbarui di `trades` (harga tutup, profit, `close_reason` sesuai aturan BSD).

**Alur alternatif / gagal:**
- Order ditolak/requote -> validasi ulang, 1 retry, lalu `trades.status = rejected`, `risk_events` (`broker_error`).
- Bot restart saat ada posisi -> rekonsiliasi saat start mengambil alih posisi ber-magic number bot.
- Posisi ber-magic bot ada di MT5 tetapi tidak ada di database -> dicatat sebagai `trades` dengan `signal_id` null, `risk_amount` dihitung dari SL saat diambil alih, `close_reason` kelak `unknown` bila tak terlacak.

### F-06 Dashboard web lokal
**Pemicu:** owner membuka `http://127.0.0.1:8000`.
**Alur utama:**
1. Halaman memuat `/api/status` dan data layar, lalu polling tiap 5 detik.
2. Owner mengubah pengaturan di S-04 -> `PUT /api/settings` dengan token -> tersimpan -> berlaku siklus berikutnya.
3. Tombol kill switch memanggil `POST /api/kill-switch`.

**Alur alternatif / gagal:**
- Backend tidak merespons -> banner merah "Bot tidak terjangkau", data terakhir diberi tanda usang.
- Nilai pengaturan di luar batas (mis. risiko > 2%) -> ditolak dengan pesan validasi; tidak tersimpan.
- Token tidak ada/salah -> 401, pesan "Token lokal tidak valid".
- Header `Host` asing -> 400 (anti DNS rebinding).
- Ubah `symbol_map` saat ada posisi terbuka pada simbol itu -> 409, pesan "Tutup posisi dulu".
- Kombinasi risiko melanggar `risk_per_trade_pct` x `max_open_positions` <= `max_daily_loss_pct` -> 400 dengan penjelasan.

### F-07 Jurnal & evaluasi performa
**Pemicu:** akhir hari UTC (otomatis), atau tombol "Buat ringkasan" di S-05.
**Alur utama:**
1. Hitung statistik dari `trades` dan `daily_stats`.
2. Kirim statistik (bukan data sensitif) ke model aktif pertama di `ai_models` untuk ringkasan teks; simpan ke `journal_entries`.
3. S-05 menampilkan statistik, ringkasan, dan progres terhadap kriteria kelayakan live.

**Alur alternatif / gagal:**
- Tidak ada trade pada periode -> statistik nol, ringkasan "tidak ada trade".
- AI gagal -> statistik tetap tersimpan, `ai_summary` kosong, tombol coba lagi.

### F-08 Evaluasi & pelajaran AI
**Pemicu:** trade tertutup (refleksi + usulan); `lesson_review_utc` Sabtu 00:00 UTC (verifikasi, penentang, penerapan).
**Alur utama:**
1. Trade tertutup -> tiap model yang ikut memutuskan menulis refleksi (`ai_reflections`) dan boleh mengusulkan pelajaran terstruktur.
2. Kode memvalidasi usulan (kunci fitur dikenal, hanya memperketat) dan menghitung statistik dari riwayat; lolos `lesson_min_trades` -> `ai_lessons.status = pending`.
3. Sabtu 00:00 UTC: kode memverifikasi ulang pelajaran pending dan aktif; yang kedaluwarsa -> `expired`.
4. Penentang (model penyedia lain) menilai: `reject` -> pending menjadi `rejected`, aktif menjadi `disabled`.
5. Sisa pending -> `active` (maks `lesson_max_active` per model); jika set berubah, `prompt_versions` baru berlaku Senin.
6. Setiap siklus: efek pelajaran aktif diterapkan pada opini model pemilik sebelum konsensus; `ai_opinions.raw_direction` dan `lessons_applied` dicatat.
7. Setelah `rollback_min_trades` trade di versi baru: profit factor lebih buruk dari versi sebelumnya -> rollback ke set versi sebelumnya.

**Alur alternatif / gagal:**
- Usulan melonggarkan / kunci fitur tidak dikenal -> ditolak kode (`rejected`).
- Penentang error/timeout, atau tidak ada model aktif dari penyedia lain -> pending tetap pending; set aktif tidak berubah.
- `lessons_enabled` = 0 -> efek dan teks pelajaran tidak dipakai; prompt dasar.
- `lessons_frozen` = 1 -> langkah 3-5 dan 7 hanya mencatat penilaian, status tidak berubah.

```mermaid
flowchart TD
  T[Trade tertutup] --> R[Refleksi tiap model]
  R --> U[Usulan pelajaran]
  U --> V{Kode: hanya memperketat dan >= 20 trade?}
  V -- Tidak --> X[rejected]
  V -- Ya --> P[pending]
  P --> W[Sabtu 00:00 UTC: penentang penyedia lain]
  W -- reject --> X
  W -- keep --> A[active mulai Senin, prompt_version baru]
  A --> K{Setelah 15 trade: PF lebih buruk?}
  K -- Ya --> RB[rollback ke versi sebelumnya]
  K -- Tidak --> A
```

## 5. State Layar
| Layar | Kosong | Loading | Error | Sukses |
|---|---|---|---|---|
| S-01 | "Belum ada sinyal" + status bot tetap tampil | Skeleton kartu | Banner "Bot tidak terjangkau" | Kartu status, equity, posisi, sinyal terakhir |
| S-02 | "Belum ada sinyal. Menunggu candle M15 berikutnya" | Skeleton tabel | Pesan + tombol muat ulang | Tabel sinyal; baris diperluas menampilkan opini tiap AI |
| S-03 | "Belum ada trade" | Skeleton tabel | Pesan + tombol muat ulang | Tab Terbuka / Riwayat |
| S-04 | Nilai default terisi | Spinner di tombol Simpan | Pesan validasi per field | Toast "Tersimpan, berlaku siklus berikutnya" |
| S-05 | "Belum ada data jurnal" | Skeleton | Pesan + tombol coba lagi | Kartu statistik, ringkasan AI, progres kelayakan live, tabel pelajaran per model + hasil penentang |

## 6. Aturan Lintas Layar
- Tidak ada login; semua layar hanya via `127.0.0.1`.
- Banner mode selalu tampil di header: "DEMO" (netral) atau "LIVE" (merah, mencolok).
- Aksi destruktif (kill switch, reset, "Tutup semua sekarang") butuh dialog konfirmasi. Mode tidak bisa diubah dari UI.
- Tidak ada notifikasi eksternal; peristiwa penting tampil sebagai baris `risk_events` di S-01.
