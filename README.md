# vibe-starter

Template proyek kosong untuk vibe coding terstruktur dengan Claude Code.
Berisi satu skill, `vibe-docs`, yang mengubah ide aplikasi menjadi 6 dokumen
spesifikasi lalu membangun aplikasinya langkah demi langkah.

| Dokumen | Isi |
|---|---|
| `docs/PRD.md` | Produk, fitur MVP, scope |
| `docs/TRD.md` | Stack, arsitektur, konvensi kode |
| `docs/AFD.md` | Alur pengguna dan layar |
| `docs/DBD.md` | Panduan desain |
| `docs/BSD.md` | Skema database dan API |
| `docs/IPD.md` | Rencana kerja bertahap |

## Cara memakai

1. Di GitHub, buka **Settings** repo ini dan centang **Template repository** (sekali saja).
2. Untuk proyek baru, klik **Use this template** lalu **Create a new repository**.
3. Buka repo baru itu di Claude Code, lalu jalankan:

```
/vibe-docs init <ide aplikasi>
```

Setelah dokumen disetujui, kerjakan satu langkah per sesi:

```
/vibe-docs build
```

Perintah lain: `/vibe-docs update` (ubah kebutuhan) dan `/vibe-docs check` (cek konsistensi dokumen).

## Struktur

```
.claude/skills/vibe-docs/
  SKILL.md        # instruksi skill
  templates/      # template 6 dokumen + CLAUDE.md
```
