# TradingBot AI (MT5)

Bot trading otomatis Windows untuk MetaTrader 5 (XAUUSD, EURUSD): beberapa model AI (Claude + OpenAI) menganalisa dengan strategi diskresi penuh dan belajar dari pelajaran terkendali, order hanya dieksekusi jika semua setuju dan lolos batas risiko. Tahap awal: akun demo.

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
5. Sebelum menyatakan selesai: jalankan `pytest`, `ruff check .`, dan cek "Selesai jika". Laporkan hasil apa adanya.
6. Centang langkah di IPD hanya setelah terbukti lolos.
7. Jangan mulai membangun sebelum user menyetujui dokumen (`/vibe-docs build`).

## Perintah
- Install: `pip install -e .[dev]`
- Jalankan bot + dashboard: `python -m tradingbot`
- Test: `pytest`
- Lint: `ruff check .` dan `ruff format .`
- Build: tidak ada

## Aturan Keras
- Jangan commit secret; gunakan environment variable (`.env.example` sebagai daftar).
- Jangan hapus atau timpa data/migrasi yang sudah ada tanpa konfirmasi.
- Mode default dan fallback selalu `demo`. Jangan pernah mengubah/mengaktifkan mode `live` dari kode atau tes; penjaga live (TRD bagian 5) tidak boleh dilemahkan.
- Jangan kirim order tanpa SL dan TP. Lot dihitung kode, bukan AI.
- Bot hanya mengelola posisi dengan magic number bot; posisi lain di akun tidak boleh disentuh.
- Pelajaran AI (F-08) hanya boleh memperketat keputusan dan efeknya diterapkan kode; tidak pernah mengubah batas risiko, lot, SL/TP, kill switch, atau rem tambahan.
- `MetaTrader5` hanya boleh dipanggil dari `src/tradingbot/broker/mt5.py`; tes memakai `MockBroker` dan AI palsu (tanpa API key, tanpa uang).
- Semua waktu disimpan UTC. Tidak ada SQL mentah tanpa parameter. Tidak ada API key di log.
