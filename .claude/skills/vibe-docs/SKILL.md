---
name: vibe-docs
description: Membuat 6 dokumen perencanaan (PRD, TRD, AFD, DBD, BSD, IPD) yang ringkas dan siap dibaca AI, lalu membangun aplikasi langkah demi langkah dari dokumen tersebut. Gunakan saat user ingin memulai proyek baru, "vibe coding" yang terstruktur, membuat spesifikasi/PRD/rencana implementasi, atau melanjutkan pengerjaan dari docs yang sudah ada. Argumen - init (default), build, update, check.
argument-hint: "[init | build | update | check] [ide singkat]"
---

# vibe-docs

Mengubah ide aplikasi menjadi 6 dokumen spesifikasi, lalu membangun aplikasinya bertahap.
Tujuannya: hasil vibe coding konsisten, tidak melenceng dari scope, dan bisa dilanjutkan di sesi baru.

Balas dalam bahasa yang dipakai user (default Bahasa Indonesia). Istilah teknis boleh tetap bahasa Inggris.

## Mode (dari `$ARGUMENTS`)

| Argumen | Aksi |
|---|---|
| kosong / `init` | Fase 1-5 di bawah: wawancara, buat dokumen, cek konsistensi |
| `build` | Kerjakan **satu** langkah berikutnya dari `docs/IPD.md` (Fase 6) |
| `update` | Ubah dokumen sesuai perubahan kebutuhan, lalu sinkronkan dokumen terkait |
| `check` | Hanya jalankan cek konsistensi (Fase 4) dan laporkan temuan |

Teks setelah mode (jika ada) dianggap ide awal user.

## Prinsip menulis dokumen untuk AI

Dokumen ini dibaca ulang oleh AI di setiap sesi, jadi:

1. **Ringkas.** Target 1-2 halaman per dokumen. Tanpa basa-basi, tanpa teori.
2. **Tegas dan terukur.** Tulis "maks 5 alamat per pengguna", bukan "beberapa alamat". Hindari kata "cepat", "mudah", "bagus" tanpa angka.
3. **ID yang stabil.** Fitur = `F-01`, `F-02`... Layar = `S-01`... Entitas data memakai nama tabel persis sama di semua dokumen. Dokumen lain merujuk ID, bukan menyalin ulang isi.
4. **Scope eksplisit.** Selalu ada bagian "Di luar scope" supaya AI tidak menambah fitur sendiri.
5. **Checklist, bukan paragraf**, untuk apa pun yang akan dikerjakan atau diverifikasi.
6. **Tandai asumsi** dengan `[ASUMSI]` jika user tidak menjawab. Jangan mengarang fakta bisnis.
7. **Jangan menulis kode implementasi** di dokumen, kecuali skema, kontrak API, atau struktur folder.

## Fase 1 - Pemeriksaan awal

1. Cek apakah folder `docs/` sudah berisi salah satu dari `PRD.md TRD.md AFD.md DBD.md BSD.md IPD.md`.
   - Jika sudah ada, **jangan timpa**. Tanyakan: lanjutkan/update (`update`), atau mulai ulang (backup dulu ke `docs/_backup/`).
2. Cek apakah ada kode yang sudah ada di repo (`package.json`, `pyproject.toml`, dll.). Jika ada, ini proyek existing: baca dulu dan sesuaikan TRD dengan stack yang sudah dipakai, jangan menyarankan ganti stack tanpa alasan kuat.

## Fase 2 - Wawancara (Discovery)

Gunakan tool `AskUserQuestion`, maksimal 4 pertanyaan per putaran, 2-3 putaran. Berikan opsi pilihan dengan rekomendasi default di urutan pertama. Jangan menanyakan hal yang sudah dijelaskan user di prompt.

**Putaran 1 - Produk (untuk PRD, AFD)**
- Masalah apa yang diselesaikan, dan untuk siapa (pengguna utama)?
- Fitur inti MVP (maks 5-7). Apa yang jelas **tidak** dibuat dulu?
- Peran pengguna (hanya satu jenis, atau ada admin/member/tamu)?
- Metrik sukses atau definisi "sudah jadi" menurut user.

**Putaran 2 - Teknis (untuk TRD, BSD)**
- Platform: web, mobile, atau keduanya? Perlu responsive/PWA?
- Preferensi stack atau pengalaman user. Jika tidak ada, rekomendasikan stack paling sederhana yang cukup (satu bahasa, satu database, hosting gratis/murah) dan jelaskan alasannya singkat.
- Kebutuhan: login (email/Google), pembayaran, upload file, notifikasi, integrasi pihak ketiga, realtime.
- Data sensitif apa yang disimpan (kepatuhan, enkripsi)?

**Putaran 3 - Desain & rencana (untuk DBD, IPD)**
- Kesan/brand yang diinginkan (mis. profesional, playful, minimalis) dan referensi aplikasi serupa.
- Warna/logo/font yang sudah ada?
- Deadline atau target rilis, dan waktu yang tersedia per minggu.
- Siapa yang mengerjakan (solo + AI, atau ada tim)?

Jika user menjawab "terserah", pilih default yang masuk akal dan tandai `[ASUMSI]`.

## Fase 3 - Membuat dokumen

Buat folder `docs/` di root proyek. Untuk setiap dokumen, baca template di folder `templates/` skill ini (path relatif terhadap SKILL.md), isi sesuai hasil wawancara, lalu tulis ke `docs/`.

**Urutan wajib** (tiap dokumen bergantung pada sebelumnya):

1. `docs/PRD.md` dari `templates/PRD.md` - sumber ID fitur `F-xx`.
2. `docs/TRD.md` dari `templates/TRD.md` - stack, arsitektur, struktur folder, aturan kode.
3. `docs/AFD.md` dari `templates/AFD.md` - alur per fitur, ID layar `S-xx`, diagram Mermaid, termasuk alur gagal dan state kosong/loading/error.
4. `docs/DBD.md` dari `templates/DBD.md` - token desain (warna hex, font, spacing), komponen, aksesibilitas.
5. `docs/BSD.md` dari `templates/BSD.md` - ERD (Mermaid), tabel/kolom/tipe/constraint, indeks, aturan akses, kontrak API ringkas.
6. `docs/IPD.md` dari `templates/IPD.md` - fase dan langkah kecil berurutan dengan checkbox, setiap langkah merujuk `F-xx`, `S-xx`, tabel BSD, dan punya kriteria selesai yang bisa dites.

Setelah itu buat juga `CLAUDE.md` di root dari `templates/CLAUDE.md` (jika belum ada; jika sudah ada, tambahkan bagian "Dokumen Proyek" tanpa menghapus isi lama). File ini membuat setiap sesi Claude Code otomatis tahu cara bekerja di proyek ini.

Aturan kualitas IPD:
- Satu langkah = pekerjaan yang bisa selesai dan dites dalam satu sesi (kira-kira 1-3 jam). Pecah jika lebih besar.
- Langkah 1 selalu setup proyek + struktur folder + lint/format + commit pertama.
- Urutkan: fondasi (setup, database, auth) -> alur inti -> fitur pendukung -> polesan -> testing & rilis.
- Setiap langkah punya "Selesai jika:" berisi perilaku yang bisa diverifikasi (perintah tes atau tindakan manual).

## Fase 4 - Cek konsistensi

Sebelum menunjukkan hasil, verifikasi dan perbaiki sendiri:

- [ ] Setiap `F-xx` di PRD muncul di AFD (alur), BSD (data, jika perlu), dan IPD (langkah).
- [ ] Setiap `S-xx` di AFD punya komponen/gaya yang tercakup di DBD.
- [ ] Setiap tabel/kolom yang dirujuk di AFD, TRD, atau IPD ada di BSD dengan nama persis sama.
- [ ] Stack di TRD cukup untuk semua kebutuhan non-fungsional di PRD.
- [ ] Tidak ada fitur di IPD yang tidak ada di PRD (dan sebaliknya).
- [ ] Semua `[ASUMSI]` terkumpul di satu daftar.
- [ ] Tidak ada placeholder `{{...}}` atau `TODO` tersisa.

Mode `check` berhenti di sini dan melaporkan hasilnya sebagai daftar temuan + saran perbaikan.

## Fase 5 - Presentasi dan persetujuan

Tampilkan ringkasan singkat (bukan seluruh isi dokumen):
- Daftar fitur MVP dan hal yang di luar scope.
- Stack yang dipilih beserta alasan satu kalimat.
- Jumlah langkah di IPD dan estimasi total.
- Daftar `[ASUMSI]` yang perlu dikonfirmasi.

Minta user mengonfirmasi atau mengoreksi. **Jangan mulai membuat kode** sebelum user menyetujui. Setelah setuju, tawarkan menjalankan `/vibe-docs build` untuk langkah pertama.

## Fase 6 - Build (satu langkah per eksekusi)

Dipakai pada mode `build`, atau saat user berkata "lanjut"/"kerjakan langkah berikutnya".

1. Baca `CLAUDE.md`, `docs/IPD.md`, lalu hanya dokumen yang relevan dengan langkah tsb (mis. BSD untuk langkah database, DBD untuk langkah UI).
2. Ambil **satu** langkah pertama yang belum dicentang `[ ]`. Sebutkan ke user langkah mana yang dikerjakan.
3. Kerjakan sesuai spesifikasi. Ikuti nama tabel, ID, struktur folder, dan konvensi dari dokumen. Jika spesifikasi bertentangan atau kurang, **berhenti dan tanyakan**; jangan menebak.
4. Jangan menambah fitur, library, atau refactor di luar langkah ini. Jika menemukan hal penting di luar scope, catat di bagian "Catatan & Utang Teknis" di `IPD.md`.
5. Verifikasi: jalankan tes/lint/build dan cek kriteria "Selesai jika". Laporkan hasil apa adanya, termasuk yang gagal.
6. Jika lolos: centang langkah di `IPD.md`, tambahkan satu baris catatan (tanggal + keputusan penting), lalu tawarkan commit.
7. Jika ada keputusan yang mengubah spesifikasi (skema, alur, stack), perbarui dokumen terkait pada saat itu juga (jalankan logika mode `update`).
8. Berhenti. Laporkan: apa yang selesai, apa yang dites, dan langkah berikutnya. Jangan lanjut ke langkah berikutnya tanpa diminta.

## Mode `update`

1. Tanyakan atau tangkap perubahan yang diinginkan.
2. Tentukan dokumen yang terdampak mengikuti rantai: PRD -> (TRD, AFD) -> (DBD, BSD) -> IPD.
3. Ubah dokumen sumber dulu, lalu sinkronkan yang turunan. Pertahankan ID yang ada; jangan menomori ulang. Fitur yang dibuang ditandai `[DIBATALKAN]`, bukan dihapus.
4. Jika ada langkah IPD yang sudah selesai tetapi terdampak, tambahkan langkah baru "migrasi/penyesuaian", jangan membuka ulang yang sudah dicentang.
5. Jalankan Fase 4 dan laporkan ringkasan perubahan.

## Hal yang dihindari

- Menimpa dokumen atau kode user tanpa konfirmasi.
- Dokumen panjang dan generik yang tidak spesifik pada proyek ini.
- Menambah teknologi "keren" yang tidak dibutuhkan MVP.
- Mengerjakan beberapa langkah IPD sekaligus.
- Mengklaim langkah selesai tanpa menjalankan verifikasinya.
