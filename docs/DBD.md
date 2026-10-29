# DBD - TradingBot AI (MT5)

> Versi: 0.1 | Diperbarui: 2026-10-29 | Merujuk: PRD.md, AFD.md

## 1. Karakter Brand
- Kata kunci: tenang, jelas, tepercaya.
- Nada teks: singkat, netral, Bahasa Indonesia; angka dan status lebih utama daripada kalimat. Contoh: "Konsensus: SELL (2/2 setuju)", bukan "Wah, kedua AI setuju!".
- Referensi: antarmuka terminal trading (TradingView, MT5) untuk kepadatan data; dashboard monitoring gelap yang tidak melelahkan mata.
- Hindari: warna ramai, animasi berlebihan, emoji, kesan "kasino" (konfeti, nada menjanjikan untung).

## 2. Design Tokens
**Warna (tema gelap, default)**
| Token | Hex | Pemakaian |
|---|---|---|
| primary | #3B82F6 | Tombol utama, link, tab aktif |
| primary-hover | #2563EB | Hover tombol utama |
| background | #0F1419 | Latar halaman |
| surface | #1A2129 | Kartu, tabel, modal |
| border | #2A3441 | Garis pemisah |
| text | #E6EAF0 | Teks utama |
| text-muted | #9AA7B8 | Teks sekunder |
| success | #22C55E | Profit, beli, status sehat |
| danger | #EF4444 | Rugi, jual, kill switch, mode LIVE |
| warning | #F59E0B | Peringatan, data usang, diblokir |

Dark mode: tema gelap adalah satu-satunya tema di MVP. Tema terang: di luar scope.
Arah buy/sell tidak boleh dibedakan hanya lewat warna: selalu sertakan teks "BUY"/"SELL".

**Tipografi**
- Font: Inter (sistem fallback: Segoe UI, sans-serif); angka tabel memakai `font-variant-numeric: tabular-nums`.
- Skala: h1 24px, h2 18px, body 14px, caption 12px; line-height 1.5.

**Spacing & bentuk**
- Skala spacing: 4 / 8 / 12 / 16 / 24 / 32.
- Radius: 8px kartu, 6px tombol/input | Bayangan: tidak dipakai (cukup border).
- Grid & lebar maks konten: 12 kolom, lebar maks 1280px.

## 3. Komponen
| Komponen | Varian | State wajib |
|---|---|---|
| Button | primary, secondary, ghost, danger | default, hover, focus, disabled, loading |
| Input | number, text, select, toggle | default, focus, error, disabled |
| Card (statistik) | angka besar + label + delta | default, loading (skeleton), error |
| Tabel data | rapat, baris dapat diperluas | default, kosong, loading, error |
| Badge | mode (DEMO/LIVE), arah (BUY/SELL/HOLD), status (open/closed/rejected/blocked/skip), status pelajaran (pending/active/rejected/disabled/expired/rolled_back) | -- |
| Banner | info, warning, danger | tampil/tutup (danger terkait kill switch tidak bisa ditutup) |
| Dialog konfirmasi | untuk kill switch, reset, tutup semua (panic) | default, loading |
| Toast | sukses, error | muncul 4 detik |
| Navigasi | bilah atas (5 menu) + tombol kill switch | aktif, hover, focus |

### Pemetaan layar ke komponen
| Layar | Komponen utama |
|---|---|
| S-01 Dashboard | Card statistik (saldo, equity, P/L hari ini), Badge mode, Tabel posisi terbuka, Tabel sinyal terakhir, Banner, tombol Kill switch + Dialog |
| S-02 Sinyal & Opini AI | Tabel data (baris dapat diperluas), Badge arah/status, Input select filter simbol |
| S-03 Posisi & Riwayat | Tabel data dengan tab Terbuka/Riwayat, Badge status, tautan ke S-02 |
| S-04 Risiko & Pengaturan | Input number/toggle/select, select kandidat simbol broker (`symbol_map`), daftar model AI (`ai_models`: beberapa model per penyedia, tambah/aktif/nonaktif), toggle `lessons_enabled` dan `lessons_frozen`, pengaturan rem tambahan, Button simpan, Button danger "Tutup semua sekarang", Dialog konfirmasi (kill switch, reset, panic), Toast |
| S-05 Jurnal & Performa | Card statistik, Tabel harian/mingguan, blok ringkasan AI, indikator progres kelayakan live, Tabel pelajaran per model (Badge status, kondisi, efek, bukti, catatan penentang), riwayat `prompt_versions` |

## 4. Responsivitas
| Breakpoint | Lebar | Perilaku layout |
|---|---|---|
| mobile | < 640px | Satu kolom; tabel dapat digulir horizontal. Hanya untuk melihat, bukan target utama. |
| tablet | 640-1024px | Kartu 2 kolom |
| desktop | > 1024px | Kartu 4 kolom, tabel penuh (target utama) |

Pendekatan: desktop-first (dipakai di PC Windows), tetap tidak pecah di layar kecil.

## 5. Aksesibilitas
- Kontras teks minimal 4.5:1 (token di atas sudah dipilih untuk latar gelap).
- Target klik minimal 40x40px untuk tombol aksi; kill switch minimal 44x44px.
- Fokus keyboard terlihat (outline 2px primary); semua aksi bisa dicapai tanpa mouse.
- Status tidak hanya lewat warna (selalu ada teks/ikon); form punya label.
- Banner status penting memakai `role="alert"`.

## 6. Aset
- Logo/ikon: teks "TradingBot" tanpa logo; ikon memakai set SVG inline sederhana (tanpa library besar).
- Ilustrasi/gambar: tidak ada.
- Font: Inter dari Google Fonts atau berkas lokal di `web/static/fonts/` (lokal diutamakan agar jalan offline).

## 7. Do & Don't
| Do | Don't |
|---|---|
| Tampilkan mode (DEMO/LIVE) di header setiap saat | Menyembunyikan mode di halaman pengaturan saja |
| Tampilkan alasan blokir/skip secara eksplisit | Menampilkan "gagal" tanpa alasan |
| Kill switch selalu terlihat dan butuh konfirmasi | Menaruh aksi destruktif tanpa konfirmasi |
| Angka rata kanan, tabular, dengan satuan | Angka tanpa satuan atau pembulatan acak |
| Tandai data usang (>30 detik) dengan warna warning + teks | Menampilkan data lama seolah terkini |
