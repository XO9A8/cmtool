# eFootball Club Management & Analytics System — Database Seed Overview

This document describes the sample data populated in the PostgreSQL database (`efootball_db`) for testing, demonstration, and development of the backend API and Flutter mobile client.

---

## 1. Overview of Seeded Data

- **Total Users / Players**: 50 active accounts with real-world player names across 5 clubs.
- **Clubs**: 5 fully populated clubs with 10 players each.
- **Player Dossier & Compliance Metadata**: Full registration dossier, contact channels, and compliance status seeded for every player (matching official registry specifications).
- **Tournaments**: 4 tournaments covering multiple stages (**Halfway Finished**, **Nearly Finished**, and **Completed/Finished**).
- **Default Password for All Users**: `password123` (argon2id hashed).

---

## 2. Clubs & Roster Breakdown (5 Clubs, 10 Players Each)

### 1. Apex Esports Club
- **Club ID**: `a0000000-0000-0000-0000-000000000001`
- **Invite Code**: `APEX2026`
- **Owner / Captain**: `erling_haaland` (Erling Haaland)
- **Roster (10 Players)**:
  1. `erling_haaland` (Admin | Captain | Elo: 1850 | Form: 82.5 | Tiki-Taka)
  2. `kevin_debruyne` (Organizer | Elo: 1810 | Form: 78.0 | Possession)
  3. `phil_foden` (Phil Foden) (Player | Elo: 1720 | Form: 71.0 | Out-Wide)
  4. `rodri_hernandez` (Player | Elo: 1750 | Form: 75.0 | High-Press)
  5. `bernardo_silva` (Player | Elo: 1690 | Form: 68.0 | Tiki-Taka)
  6. `ruben_dias` (Ruben Dias) (Player | Elo: 1640 | Form: 62.0 | Long-Ball)
  7. `jack_grealish` (Player | Elo: 1580 | Form: 56.0 | Counter-Attack)
  8. `julian_alvarez` (Player | Elo: 1610 | Form: 60.0 | Out-Wide)
  9. `ederson_moraes` (Player | Elo: 1550 | Form: 52.0 | Defensive)
  10. `manuel_akanji` (Player | Elo: 1520 | Form: 48.0 | Defensive)

---

### 2. Cyber Strikers FC
- **Club ID**: `a0000000-0000-0000-0000-000000000002`
- **Invite Code**: `CYBER99`
- **Owner / Captain**: `kylian_mbappe` (Kylian Mbappe)
- **Roster (10 Players)**:
  1. `kylian_mbappe` (Admin | Captain | Elo: 1880 | Form: 88.0 | Counter-Attack)
  2. `jude_bellingham` (Organizer | Elo: 1840 | Form: 81.0 | Possession)
  3. `vinicius_jr` (Player | Elo: 1820 | Form: 79.0 | Counter-Attack)
  4. `luka_modric` (Luka Modric) (Player | Elo: 1760 | Form: 73.0 | Tiki-Taka)
  5. `toni_kroos` (Player | Elo: 1740 | Form: 70.0 | Possession)
  6. `rodrygo_goes` (Player | Elo: 1700 | Form: 66.0 | Out-Wide)
  7. `federico_valverde` (Player | Elo: 1680 | Form: 64.0 | High-Press)
  8. `antonio_rudiger` (Player | Elo: 1620 | Form: 58.0 | Defensive)
  9. `thibaut_courtois` (Thibaut Courtois) (Player | Elo: 1600 | Form: 55.0 | Defensive)
  10. `eduardo_camavinga` (Player | Elo: 1560 | Form: 50.0 | High-Press)

---

### 3. Titan Elite Gaming
- **Club ID**: `a0000000-0000-0000-0000-000000000003`
- **Invite Code**: `TITAN77`
- **Owner / Captain**: `harry_kane` (Harry Kane)
- **Roster (10 Players)**:
  1. `harry_kane` (Admin | Captain | Elo: 1830 | Form: 80.0 | Counter-Attack)
  2. `jamal_musiala` (Organizer | Elo: 1790 | Form: 76.0 | Tiki-Taka)
  3. `leroy_sane` (Player | Elo: 1710 | Form: 67.0 | Out-Wide)
  4. `joshua_kimmich` (Joshua Kimmich) (Player | Elo: 1730 | Form: 69.0 | Possession)
  5. `alphonso_davies` (Player | Elo: 1670 | Form: 63.0 | High-Press)
  6. `manuel_neuer` (Player | Elo: 1650 | Form: 61.0 | Defensive)
  7. `thomas_muller` (Player | Elo: 1620 | Form: 57.0 | Counter-Attack)
  8. `kingsley_coman` (Player | Elo: 1590 | Form: 54.0 | Out-Wide)
  9. `dayot_upamecano` (Player | Elo: 1540 | Form: 49.0 | Long-Ball)
  10. `leon_goretzka` (Player | Elo: 1570 | Form: 52.0 | High-Press)

---

### 4. Galacticos FC
- **Club ID**: `a0000000-0000-0000-0000-000000000004`
- **Invite Code**: `GALA2026`
- **Owner / Captain**: `lionel_messi` (Lionel Messi)
- **Roster (10 Players)**:
  1. `lionel_messi` (Admin | Captain | Elo: 1890 | Form: 90.0 | Tiki-Taka)
  2. `luis_suarez` (Organizer | Elo: 1770 | Form: 74.0 | Counter-Attack)
  3. `sergio_busquets` (Player | Elo: 1720 | Form: 68.0 | Possession)
  4. `jordi_alba` (Player | Elo: 1660 | Form: 62.0 | Out-Wide)
  5. `angel_dimaria` (Player | Elo: 1740 | Form: 71.0 | Counter-Attack)
  6. `lautaro_martinez` (Player | Elo: 1780 | Form: 75.0 | High-Press)
  7. `alexis_macallister` (Player | Elo: 1690 | Form: 65.0 | Possession)
  8. `enzo_fernandez` (Player | Elo: 1670 | Form: 63.0 | Tiki-Taka)
  9. `emiliano_martinez` (Player | Elo: 1650 | Form: 60.0 | Defensive)
  10. `nicolas_otamendi` (Player | Elo: 1530 | Form: 48.0 | Defensive)

---

### 5. Vanguard eSports
- **Club ID**: `a0000000-0000-0000-0000-000000000005`
- **Invite Code**: `VANGUARD10`
- **Owner / Captain**: `cristiano_ronaldo` (Cristiano Ronaldo)
- **Roster (10 Players)**:
  1. `cristiano_ronaldo` (Admin | Captain | Elo: 1870 | Form: 86.0 | Counter-Attack)
  2. `bruno_fernandes` (Organizer | Elo: 1800 | Form: 77.0 | Possession)
  3. `rafael_leao` (Player | Elo: 1750 | Form: 72.0 | Out-Wide)
  4. `joao_felix` (Player | Elo: 1690 | Form: 66.0 | Tiki-Taka)
  5. `ruben_neves` (Player | Elo: 1660 | Form: 62.0 | Long-Ball)
  6. `diogo_jota` (Player | Elo: 1710 | Form: 68.0 | High-Press)
  7. `joao_cancelo` (Player | Elo: 1700 | Form: 67.0 | Out-Wide)
  8. `pepe_ferreira` (Player | Elo: 1600 | Form: 56.0 | Defensive)
  9. `diogo_costa` (Player | Elo: 1620 | Form: 58.0 | Defensive)
  10. `nuno_mendes` (Player | Elo: 1640 | Form: 60.0 | High-Press)

---

## 3. Player Dossier, Contact & Compliance Metadata

Every player profile stores complete registry dossier attributes:

| Field | Description / Example |
| --- | --- |
| **EFOOTBALL GAME ID** | Unique in-game handle (e.g., `ASAA-625-821-344`, `EFBT-912-441-002`) |
| **PREFERRED FOOT** | `RIGHT` / `LEFT` |
| **JERSEY NUMBER** | Player number (e.g., `77`, `10`, `9`, `17`) |
| **SYSTEM DEVICE** | Hardware node (e.g., `REDMI NOTE 14 PRO+`, `IPHONE 15 PRO MAX`, `SAMSUNG S24 ULTRA`) |
| **FACEBOOK / LINK** | Facebook social URL & handle (e.g., `HTTPS://WWW.FACEBOOK.COM/JONAYET01`, `JONAYET01`) |
| **BLOOD GROUP** | Biometric blood classification (e.g., `O+`, `A+`, `B+`, `AB+`) |
| **DISTRICT** | Home district / region (e.g., `BOGURA`, `DHAKA`, `CHITTAGONG`, `SYLHET`) |
| **DATE OF BIRTH** | Birth date (e.g., `11/3/03`, `2003-03-11`) |
| **REGISTRAR JOINED** | System registration timestamp (e.g., `26/7/26`) |
| **CONTRACT START / END** | Active club contract term (e.g., `29/7/26` to `25/1/27`) |
| **EMAIL NODE & PHONE** | Contact node details (e.g., `2107023.JONAYET@GMAIL.COM`, `01831502884`) |
| **NODE STATE / AUTH STATUS** | Compliance state (`ACTIVE`, `CAPTAIN`, `CENTRAL FEDERATION`) |

---

## 4. Tournaments & Progress Stages

### 1. Season 1 Apex Champions League (**Halfway Stage**)
- **ID**: `b0000000-0000-0000-0000-000000000001`
- **Format**: `league`
- **Status**: `active`
- **Progress**: 5 rounds played, 5 rounds remaining.

#### Standings Table (Halfway)
| Rank | Player | Played | Won | Drawn | Lost | GF | GA | GD | Points |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `erling_haaland` | 5 | 4 | 1 | 0 | 14 | 4 | +10 | **13** |
| 2 | `kevin_debruyne` | 5 | 3 | 1 | 1 | 11 | 6 | +5 | **10** |
| 3 | `phil_foden` | 5 | 3 | 0 | 2 | 9 | 7 | +2 | **9** |
| 4 | `rodri_hernandez` | 5 | 2 | 1 | 2 | 8 | 8 | 0 | **7** |
| 5 | `bernardo_silva` | 5 | 1 | 1 | 3 | 5 | 10 | -5 | **4** |
| 6 | `ruben_dias` | 5 | 0 | 0 | 5 | 2 | 14 | -12 | **0** |

---

### 2. Summer Knockout Cup 2026 (**Nearly Finished Stage**)
- **ID**: `b0000000-0000-0000-0000-000000000002`
- **Format**: `knockout`
- **Status**: `active`
- **Progress**: Quarter-Finals and Semi-Finals completed. **Grand Finals scheduled** between `erling_haaland` and `kylian_mbappe`.

```
Quarter-Finals (Done)             Semi-Finals (Done)             Grand Finals (Scheduled)
---------------------             ------------------             ------------------------
erling_haaland (4) vs ruben_dias(0) -> erling_haaland (2)
kevin_debruyne (2) vs foden (1)      -> kevin_debruyne (1)    --> erling_haaland vs kylian_mbappe
---------------------
kylian_mbappe (3) vs shadow (1)   -> kylian_mbappe (3)
jude_bellingham (2) vs messi (1)    -> jude_bellingham (1)
```

---

### 3. Cyber Strikers Round Robin (**Completed Stage**)
- **ID**: `b0000000-0000-0000-0000-000000000003`
- **Format**: `round_robin`
- **Status**: `completed`

---

### 4. Vanguard Masters League (**Completed Stage**)
- **ID**: `b0000000-0000-0000-0000-000000000004`
- **Format**: `league`
- **Status**: `completed`

---

## 5. How to Re-Seed the Database

To reset and re-populate the PostgreSQL database at any time, execute:

```bash
psql -U postgres -h 127.0.0.1 -d efootball_db -f seed.sql
```
