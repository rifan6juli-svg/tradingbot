# DBD - {{Nama Produk}}

> Versi: 0.1 | Diperbarui: {{tanggal}} | Merujuk: PRD.md, AFD.md

## 1. Karakter Brand
- Kata kunci: {{3 kata, mis. bersih, hangat, tepercaya}}
- Nada teks: {{formal/santai, contoh kalimat}}
- Referensi: {{aplikasi/situs yang menjadi acuan + apa yang diambil}}
- Hindari: {{...}}

## 2. Design Tokens
**Warna**
| Token | Hex | Pemakaian |
|---|---|---|
| primary | {{#...}} | Tombol utama, link |
| primary-hover | {{#...}} | |
| background | {{#...}} | Latar halaman |
| surface | {{#...}} | Kartu, modal |
| text | {{#...}} | Teks utama |
| text-muted | {{#...}} | Teks sekunder |
| success / warning / danger | {{#...}} | Status |

Dark mode: {{ya/tidak; jika ya, definisikan pasangan token}}

**Tipografi**
- Font: {{nama, sumber}}
- Skala: h1 {{px}}, h2 {{px}}, body {{px}}, caption {{px}}; line-height {{...}}

**Spacing & bentuk**
- Skala spacing: {{4/8/12/16/24/32}}
- Radius: {{...}} | Bayangan: {{...}}
- Grid & lebar maks konten: {{...}}

## 3. Komponen
| Komponen | Varian | State wajib |
|---|---|---|
| Button | primary, secondary, ghost, danger | default, hover, focus, disabled, loading |
| Input | text, password, select | default, focus, error, disabled |
| Card | {{...}} | {{...}} |
| Modal / Toast | {{...}} | {{...}} |
| Navigasi | {{...}} | {{...}} |

## 4. Responsivitas
| Breakpoint | Lebar | Perilaku layout |
|---|---|---|
| mobile | < 640px | {{...}} |
| tablet | 640-1024px | {{...}} |
| desktop | > 1024px | {{...}} |

Pendekatan: {{mobile-first}}

## 5. Aksesibilitas
- Kontras teks minimal 4.5:1
- Target sentuh minimal 44x44px
- Fokus keyboard terlihat; semua aksi bisa dicapai tanpa mouse
- Gambar bermakna punya teks alternatif; form punya label

## 6. Aset
- Logo/ikon: {{lokasi file / library ikon}}
- Ilustrasi/gambar: {{sumber}}

## 7. Do & Don't
| Do | Don't |
|---|---|
| {{...}} | {{...}} |
