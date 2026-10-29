# IPD - {{Nama Produk}}

> Versi: 0.1 | Diperbarui: {{tanggal}} | Merujuk: PRD, TRD, AFD, DBD, BSD

## Cara memakai
Kerjakan **satu langkah per sesi**, berurutan. Centang `[x]` hanya jika kriteria "Selesai jika" terbukti lolos. Jangan mengerjakan fitur di luar langkah yang aktif.

## Ringkasan Fase
| Fase | Tujuan | Langkah | Estimasi |
|---|---|---|---|
| 1 | Fondasi | 1-{{n}} | {{...}} |
| 2 | Alur inti | {{...}} | {{...}} |
| 3 | Fitur pendukung | {{...}} | {{...}} |
| 4 | Polesan & rilis | {{...}} | {{...}} |

## Fase 1 - Fondasi

- [ ] **1. Setup proyek**
  - Rujukan: TRD bagian 1, 3, 4
  - Kerjakan: inisialisasi proyek, struktur folder, lint/format, `.env.example`, `.gitignore`, commit pertama
  - Selesai jika: `{{perintah dev}}` berjalan, `{{lint}}` dan `{{build}}` lolos

- [ ] **2. Database & skema**
  - Rujukan: BSD bagian 2-4
  - Kerjakan: migrasi untuk {{tabel}}, seed dev
  - Selesai jika: migrasi bisa dijalankan dari nol; seed terisi; tes skema lolos

- [ ] **3. Autentikasi**
  - Rujukan: F-{{xx}}, AFD S-{{xx}}, TRD bagian 5
  - Selesai jika: {{daftar, login, logout berfungsi; rute terlindungi menolak tamu}}

## Fase 2 - Alur Inti

- [ ] **4. {{nama langkah}}**
  - Rujukan: F-{{xx}}, S-{{xx}}, tabel {{...}}, DBD komponen {{...}}
  - Kerjakan: {{...}}
  - Selesai jika: {{perilaku terverifikasi + tes}}

## Fase 3 - Fitur Pendukung

- [ ] **{{n}}. {{...}}**

## Fase 4 - Polesan & Rilis

- [ ] **{{n}}. State kosong/loading/error semua layar** (AFD bagian 4)
- [ ] **{{n}}. Aksesibilitas & responsivitas** (DBD bagian 4-5)
- [ ] **{{n}}. Tes menyeluruh dan perbaikan bug**
- [ ] **{{n}}. Deploy** (TRD bagian 6) dan cek asap di production

## Definition of Done (berlaku untuk tiap langkah)
- [ ] Sesuai spesifikasi di dokumen yang dirujuk
- [ ] Tes relevan ditulis dan lolos; lint & build lolos
- [ ] Tidak ada secret di kode; tidak ada `console.log`/debug tertinggal
- [ ] Dokumen diperbarui bila ada keputusan yang mengubah spesifikasi

## Risiko
| Risiko | Dampak | Mitigasi |
|---|---|---|
| {{...}} | {{...}} | {{...}} |

## Catatan & Utang Teknis
<!-- Tambahkan: tanggal - langkah - catatan/keputusan -->
- {{tanggal}} - {{langkah}} - {{...}}
