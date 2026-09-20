# 🐣 Steal an Egg — Analysis & Scripts

Repository riset dan analisis mendalam game Roblox **"Steal an Egg"** (Game ID: `1789906834`), beserta script exploit dan dokumentasi.

## 📁 Struktur

```
docs/                              # Dokumentasi analisis
├── ANALISIS-GAME-STEAL-AN-EGG.md  # Analisis lengkap game
└── CHEAT-STRATEGY.md              # Strategi exploit

scripts/                           # Script exploit
└── steal-an-egg-hub.lua           # Script hub utama (UI-based)

steal-an-egg-analysis/            # Riset & reverse engineering
├── source/                        # Source code reference
│   ├── nahar/all_src.lua          # Full source (3,752 baris)
│   ├── chao/bundle.lua            # Bundle source (2,658 baris)
│   └── rais/cheat.lua             # Cheat reference (314 baris)
├── BFLOADER-ANALISIS.md           # Analisis obfuscation loader
├── DEOBFUSCATION-REPORT.md        # Report attempt deobfuscasi
├── loadstring.lua                 # BFLoader script
├── loadstring_debug.lua           # Debug analysis
└── readme_*.md                    # Credit/readme dari berbagai source
```

## 📊 Ringkasan

| Kategori | File | Baris |
|----------|------|-------|
| Dokumentasi | 2 | 766 |
| Script Exploit | 1 | 2,025 |
| Source Reference | 3 | 6,724 |
| Analisis Loader | 4 | 716 |
| Readme/Credit | 5 | 42 |
| **Total** | **15** | **10,273** |

## 🎮 Game Info

- **Game:** Steal an Egg
- **Game ID:** `1789906834`
- **Genre:** Simulation / Tycoon / Pet Farming
- **Anti-Cheat:** Lemah — bypass checklist included
- **Executor:** Delta, Fluxus, Synapse X, dll

## 🔍 Remote Events Utama

| Remote | Fungsi |
|--------|--------|
| `RF/EggWorld/AskFieldEggCarry` | Steal telur dari field |
| `RF/EggWorld/AskPlaceEgg` | Deposit telur ke base |
| `RF/MonsterParasite/AskFeed` | Feed monster boss |

## ⚠️ Disclaimer

> Semua script dan analisis di repo ini **hanya untuk edukasi dan akun alternatif**. Gunakan dengan risiko sendiri. Saya tidak bertanggung jawab atas banned account.

## 📝 Credit

- Source code dari berbagai contributor (nahar, chao, rais, dll)
- BFLoader dari `hanniii1/Loader`
- Analisis dan dokumentasi: proyek ini
-
