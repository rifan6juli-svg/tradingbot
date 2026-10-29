# {{Nama Produk}}

{{Satu kalimat tentang produk ini.}}

## Dokumen Proyek (sumber kebenaran)
Baca sebelum bekerja. Jangan menebak jika dokumen tidak menjelaskan; tanyakan.

| Dokumen | Isi | Baca saat |
|---|---|---|
| `docs/PRD.md` | Fitur (F-xx), scope, kriteria penerimaan | Selalu |
| `docs/TRD.md` | Stack, struktur folder, konvensi kode | Menulis kode apa pun |
| `docs/AFD.md` | Layar (S-xx) dan alur pengguna | Mengerjakan UI/alur |
| `docs/DBD.md` | Warna, font, komponen, aksesibilitas | Mengerjakan UI |
| `docs/BSD.md` | Skema database, API, aturan akses | Menyentuh data/API |
| `docs/IPD.md` | Daftar langkah kerja + status | Menentukan tugas berikutnya |

## Cara Bekerja
1. Kerjakan **satu langkah** dari `docs/IPD.md` per permintaan, berurutan dari yang belum dicentang.
2. Jangan menambah fitur, library, atau refactor di luar langkah aktif atau di luar `Di Luar Scope` PRD. Catat ide di "Catatan & Utang Teknis" IPD.
3. Gunakan nama tabel, kolom, ID, dan rute persis seperti di dokumen.
4. Jika perlu mengubah spesifikasi, ubah dokumennya juga dan sebutkan perubahannya ke user.
5. Sebelum menyatakan selesai: jalankan `{{test}}`, `{{lint}}`, `{{build}}`, dan cek "Selesai jika". Laporkan hasil apa adanya.
6. Centang langkah di IPD hanya setelah terbukti lolos.

## Perintah
- Dev: `{{...}}`
- Test: `{{...}}`
- Lint: `{{...}}`
- Build: `{{...}}`

## Aturan Keras
- Jangan commit secret; gunakan environment variable (`.env.example` sebagai daftar).
- Jangan hapus atau timpa data/migrasi yang sudah ada tanpa konfirmasi.
- {{aturan spesifik proyek dari TRD bagian 4}}
