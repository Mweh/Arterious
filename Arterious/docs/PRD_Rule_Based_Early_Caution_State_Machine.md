# PRD Teknis — Rule-Based Early Caution dan Concern State Machine

**Produk:** Early Caution Caregiver untuk Lansia berbasis iPhone / Apple Watch  
**Versi:** MVP v1.0  
**Fokus dokumen:** Kontrak input data, rule ID, evaluasi daily condition, concern-state machine, overall status, dan kebijakan notifikasi.  
**Scope awal:** Sleep, activity/mobility, heart/recovery, serta safety event.  
**Out of scope:** Diagnosis penyakit, pengukuran tekanan darah dari Apple Watch, perubahan obat, dan rekomendasi medis individual.

---

## 1. Prinsip desain

1. **Rule engine adalah sumber kebenaran.** Semua status, severity, trigger, dan action ditentukan rule engine, bukan LLM.
2. **Baseline personal dan rule absolut dipakai bersamaan.** Baseline menjawab “berubah dari kebiasaan?”, sedangkan rule absolut menjawab “masih perlu perhatian secara umum?”.
3. **Concern tidak sama dengan daily condition.** Daily condition menilai hari ini; concern state menyimpan perjalanan masalah lintas hari.
4. **Tidak semua pelanggaran rule memicu push.** Notifikasi memakai frekuensi, state, severity, dan cooldown agar tidak terjadi alert fatigue.
5. **Event akut mengabaikan baseline.** Fall event, Apple high/low HR event, dan irregular rhythm event diproses segera.
6. **Output memakai bahasa non-diagnostik.** “Dapat berkaitan”, “perlu check-in”, dan “pantau” — bukan “pasti sakit”.

---

## 2. Input data yang digunakan

Data di bawah mengikuti struktur yang sudah tersedia. Field baseline/deviation umumnya dihitung oleh sistem setelah baseline aktif.

### 2.1 Heart / health record

```json
{
  "date": "2026-08-22",
  "resting_hr_bpm": 67,
  "resting_hr_delta_bpm": 0,
  "walking_hr_avg_bpm": 88,
  "hrv_sdnn_ms": 30,
  "hrv_pct_change": 0,
  "respiratory_rate": 15.5,
  "oxygen_saturation_pct": 97.5,
  "high_hr_event": false,
  "low_hr_event": false,
  "irregular_rhythm_event": false,
  "fall_event": false
}
```

### 2.2 Activity / mobility record

```json
{
  "date": "2026-08-22",
  "steps": 2900,
  "steps_pct_of_baseline": 101.8,
  "steps_at_1200": 720,
  "steps_at_1800": 2500,
  "exercise_minutes": 25,
  "walking_distance_km": 1.9,
  "walking_speed_mps": 0.84,
  "walking_speed_pct_change": 1.2,
  "walking_steadiness_event": false,
  "workout_active": false,
  "workout_type": null,
  "watch_wear_hours": 21.0
}
```

### 2.3 Sleep record

```json
{
  "date": "2026-08-22",
  "bedtime": "2026-08-21T22:30:00+07:00",
  "wake_time": "2026-08-22T06:00:00+07:00",
  "total_sleep_minutes": 400,
  "time_in_bed_minutes": 450,
  "awake_minutes": 50,
  "sleep_efficiency_pct": 88.9,
  "rem_minutes": 85,
  "core_minutes": 245,
  "deep_minutes": 70,
  "bedtime_deviation_minutes": 0,
  "wake_time_deviation_minutes": 0,
  "sleep_duration_deviation_minutes": 0
}
```

### 2.4 Field minimum dan kualitas data

| Domain | Field minimum | Data dianggap tidak cukup jika |
|---|---|---|
| Sleep | `bedtime`, `wake_time`, `total_sleep_minutes`, `time_in_bed_minutes` | Episode tidur utama tidak ada, total tidur tidak masuk akal, atau time in bed ≤ 0 |
| Activity | `steps`, `watch_wear_hours` | Watch dipakai <10 jam atau data step kosong |
| Heart | `resting_hr_bpm` untuk rule RHR; `hrv_sdnn_ms` opsional | Sampel RHR tidak tersedia; jangan memaksakan rule HRV |
| Safety | Semua event boolean | Event tetap valid bila `true`; baseline tidak diperlukan |

---

## 3. Waktu evaluasi

| Domain | Kapan rule dihitung | Daily condition update | Concern state update | Delivery default |
|---|---|---|---|---|
| Sleep | Setelah tidur utama berakhir | Pagi, setelah data sinkron | Setelah evaluasi pagi | Dashboard; push hanya concern baru/eskalasi |
| Activity | Checkpoint jam 12.00, 18.00, dan final jam 21.00 | Pada setiap checkpoint | Hanya jika final/day-level atau ekstrem | Dashboard *near-real-time*; push selektif |
| Heart rate | Saat data tersedia untuk tampilan | *Near-real-time* untuk display | RHR/HRV dinilai harian; event dinilai segera | Dashboard; event Apple dapat push segera |
| Workout | Saat workout aktif/selesai | Setelah session selesai | Hanya bila HR tidak pulih atau rule lain terpenuhi | Dashboard; biasanya tanpa push |
| Safety event | Saat event diterima | Langsung | Langsung ke urgent override | Push segera |

> HealthKit sync bersifat **best effort**. Dashboard boleh disebut *near-real-time*, tetapi jangan menjanjikan data Apple Watch selalu terkirim detik itu juga.

---

## 4. Kelas baseline profile

Baseline dibangun dari 14 hari awal dengan minimal 10 hari data valid. Nilai baseline per metrik menggunakan **median**, dan variasinya memakai IQR/SD. Baseline diperbarui mingguan memakai rolling window 14–28 hari; hari dengan event akut/penyakit/perjalanan dapat dikeluarkan dari pembaruan.

| Kode | Label UI | Definisi |
|---|---|---|
| `INSUFFICIENT_DATA` | Data belum cukup | Data valid <10 hari dalam 14 hari atau banyak missing data |
| `FAVORABLE_BASELINE` | Pola dasar relatif baik | Mayoritas metrik stabil dan tidak menunjukkan concern absolut berulang |
| `STABLE_WITH_NEEDS` | Pola dasar stabil, perlu dukungan | Ada indikator kurang optimal tetapi relatif stabil |
| `PERSISTENT_CONCERN_BASELINE` | Pola dasar perlu perhatian | Concern absolut muncul berulang pada masa onboarding |
| `UNSTABLE_BASELINE` | Pola dasar belum stabil | Variasi antarhari terlalu besar atau terdapat konteks akut berulang |
| `CONTEXT_REQUIRED` | Butuh konteks | Data dipengaruhi travel, rawat inap, shift, watch tidak dipakai, atau kondisi lain |

### Contoh baseline output

```json
{
  "baseline_period_days": 14,
  "valid_days": 12,
  "sleep": {
    "median_total_sleep_minutes": 400,
    "median_sleep_efficiency_pct": 88.9,
    "median_awake_minutes": 50,
    "median_bedtime": "22:30",
    "bedtime_sd_minutes": 22
  },
  "activity": {
    "median_steps_daily": 2850,
    "median_steps_at_1200": 700,
    "median_steps_at_1800": 2450,
    "median_walking_speed_mps": 0.83
  },
  "heart": {
    "median_resting_hr_bpm": 67,
    "median_hrv_sdnn_ms": 30
  }
}
```

---

## 5. Kelas daily condition

Daily condition adalah evaluasi **hari ini**. Setiap domain memiliki `relative_status` terhadap baseline serta `absolute_status` terhadap acuan umum bila tersedia.

| Kode | Label UI | Definisi | Contoh |
|---|---|---|---|
| `NO_DATA` | Data belum tersedia | Data tidak cukup atau tidak valid | Watch dipakai 4 jam; tidak ada data sleep |
| `ON_TRACK` | Stabil dibanding pola biasa | Berada dekat baseline pribadi | Baseline tidur 4j20m; hari ini 4j15m |
| `IMPROVED` | Lebih baik dari pola biasa | Perbaikan bermakna dari baseline/concern aktif | Baseline SE 70%; hari ini 82% selama beberapa hari |
| `MINOR_DEVIATION` | Ada perubahan ringan | Deviasi kecil dan belum menjadi pola | Steps 78% baseline satu hari |
| `WORSENED` | Kondisi memburuk hari ini | Deviasi besar atau threshold harian kuat | Tidur 2j45m; steps 35% baseline; RHR +20 bpm |
| `ACUTE_EVENT` | Perlu dicek segera | Event keselamatan/Apple alert | Fall event atau irregular rhythm event |

Contoh daily output:

```json
{
  "domain": "sleep",
  "daily_condition": "ON_TRACK",
  "relative_status": "ON_TRACK",
  "absolute_status": "BELOW_GENERAL_REFERENCE",
  "note": "Stabil dibanding pola biasa, tetapi durasi tidur masih di bawah acuan umum."
}
```

---

## 6. Kelas concern state

Concern state disimpan **per domain** (`sleep`, `activity`, `heart`, `safety`) dan dikelola oleh state machine. Daily condition adalah input; concern state adalah status longitudinal.

| Kode | Label UI | Definisi | Delivery |
|---|---|---|---|
| `NONE` | Tidak ada concern aktif | Tidak ada pola masalah aktif | Tidak ada push |
| `OBSERVATION` | Sedang dipantau | Ada deviasi awal, belum cukup frekuensi | Dashboard saja |
| `NEW_CONCERN` | Perubahan baru terdeteksi | Pattern/threshold baru saja terpenuhi | Push sekali jika actionable |
| `PERSISTENT_CONCERN` | Pola masih perlu perhatian | Masalah tetap ada, tanpa perburukan baru | Dashboard + ringkasan mingguan |
| `ESCALATED_CONCERN` | Kondisi memburuk | Severity naik, deviasi makin besar, atau multi-domain concern | Push baru ke caregiver |
| `IMPROVING` | Kondisi mulai membaik | Ada perbaikan konsisten 3–7 hari | Ringkasan positif opsional |
| `RESOLVED` | Kembali stabil | Tidak lagi memenuhi trigger selama recovery window | Tidak ada push |
| `URGENT_OVERRIDE` | Perlu dicek segera | Event akut; mengabaikan cooldown | Push segera/template tetap |

### State machine

```text
NONE
  └── minor deviation satu kali ──> OBSERVATION

OBSERVATION
  ├── kembali stabil ─────────────> RESOLVED ──> NONE
  ├── pattern/frekuensi terpenuhi > NEW_CONCERN
  └── deviasi ekstrem ────────────> ESCALATED_CONCERN

NEW_CONCERN
  ├── pola menetap ───────────────> PERSISTENT_CONCERN
  ├── makin berat/multi-domain ───> ESCALATED_CONCERN
  └── membaik 3–7 hari ───────────> IMPROVING

PERSISTENT_CONCERN
  ├── memburuk ───────────────────> ESCALATED_CONCERN
  └── membaik 3–7 hari ───────────> IMPROVING

IMPROVING
  ├── stabil dalam recovery window > RESOLVED ──> NONE
  └── masalah kembali ────────────> NEW_CONCERN / ESCALATED_CONCERN

ANY STATE
  └── event akut ─────────────────> URGENT_OVERRIDE
```

---

## 7. Rule catalog — Sleep (`S*`)

### 7.1 Rule harian sleep

| Rule ID | Kondisi | Daily condition | Severity | Catatan |
|---|---|---|---:|---|
| `S0` | Data sleep tidak valid/tidak tersedia | `NO_DATA` | 0 | Tidak membuat concern klinis |
| `S1` | Total sleep 6–<7 jam | `MINOR_DEVIATION` | 1 | Sedikit di bawah target umum lansia |
| `S2` | Total sleep <6 jam | `WORSENED` | 2 | Short sleep hari ini |
| `S3` | Total sleep ≤5 jam | `WORSENED` | 3 | Short sleep berat; cek konteks |
| `S4` | Total sleep >9 jam | `MINOR_DEVIATION` | 1 | Cek jika pola baru/berulang |
| `S5` | Total sleep >10 jam | `WORSENED` | 2 | Tidak darurat; perlu konteks bila berulang |
| `S6` | Sleep efficiency 80–<85% | `MINOR_DEVIATION` | 1 | Tidur agak terputus |
| `S7` | Sleep efficiency 75–<80% | `WORSENED` | 2 | Efisiensi rendah |
| `S8` | Sleep efficiency <75% | `WORSENED` | 3 | Fragmentasi tinggi |
| `S9` | Awake >30–60 menit | `MINOR_DEVIATION` | 1 | Waktu terjaga meningkat |
| `S10` | Awake >60–90 menit | `WORSENED` | 2 | Fragmentasi bermakna |
| `S11` | Awake >90 menit | `WORSENED` | 3 | Fragmentasi tinggi |
| `S12` | Bedtime deviation >30–60 menit | `MINOR_DEVIATION` | 1 | Jadwal mulai bergeser |
| `S13` | Bedtime deviation >60–120 menit | `WORSENED` | 2 | Pergeseran besar |
| `S14` | Bedtime/midpoint deviation >120 menit | `WORSENED` | 3 | Minta konteks; jangan mendiagnosis circadian disorder |
| `S15` | Tidur utama mayoritas 08.00–18.00 | `WORSENED` | 3 | Indikasi pola tidur-bangun bergeser; cek travel/shift/sakit |

### 7.2 Rule pattern sleep

| Rule ID | Kondisi frekuensi | Concern outcome | Notifikasi |
|---|---|---|---|
| `S16` | `S1` muncul ≥3 malam/7 hari | `OBSERVATION` atau `NEW_CONCERN` | Dashboard/push ringan sesuai policy |
| `S17` | `S2` muncul ≥2 malam berturut atau ≥3 malam/7 hari | `NEW_CONCERN` | Push sekali |
| `S18` | `S3` muncul ≥2 malam/7 hari | `NEW_CONCERN` high severity | Push + check-in |
| `S19` | `S7` muncul ≥2 malam berturut atau ≥3 malam/7 hari | `NEW_CONCERN` | Push sekali |
| `S20` | `S8` muncul ≥2 malam/7 hari | `NEW_CONCERN` high severity | Push + cek keluhan |
| `S21` | `S10` muncul ≥3 malam/7 hari | `NEW_CONCERN` | Push sekali |
| `S22` | `S11` muncul ≥2 malam/7 hari | `NEW_CONCERN` high severity | Push + cek keluhan |
| `S23` | `S13` muncul ≥2 malam/7 hari | `NEW_CONCERN` | Push ringan |
| `S24` | `S14` atau `S15` muncul ≥2 kali/7 hari | `ESCALATED_CONCERN` atau `NEW_CONCERN` high | Push + minta konteks |
| `S25` | SD bedtime 7 hari >60 menit | `NEW_CONCERN` | Jadwal sangat tidak teratur |
| `S26` | SD bedtime 7 hari >90 menit | `ESCALATED_CONCERN` jika concern aktif | Push baru |
| `S27` | SD total sleep 7 hari >90 menit | `NEW_CONCERN` | Lama tidur sangat berubah-ubah |
| `S28` | Sleep concern + BP pagi meningkat selama ≥2–3 hari | `ESCALATED_CONCERN` | Warning terintegrasi bila data tensi tersedia |

---

## 8. Rule catalog — Activity & mobility (`A*`)

Activity harus dibandingkan dengan baseline pada waktu yang sama. Jangan menilai steps pukul 10.00 memakai target total langkah harian.

| Rule ID | Kondisi | Daily condition | Severity | Frequency / outcome |
|---|---|---|---:|---|
| `A0` | Wear time <10 jam atau step tidak ada | `NO_DATA` | 0 | Tidak membuat concern |
| `A1` | Steps ≥85% baseline pada checkpoint/final | `ON_TRACK` | 0 | `NONE` bila tidak ada rule lain |
| `A2` | Steps 70–<85% baseline pada akhir hari | `MINOR_DEVIATION` | 1 | 1 hari → `OBSERVATION` |
| `A3` | Steps 50–<70% baseline pada akhir hari | `WORSENED` | 2 | ≥3 hari/7 hari → `NEW_CONCERN` |
| `A4` | Steps <50% baseline pada akhir hari | `WORSENED` | 3 | ≥2 hari berturut → `NEW_CONCERN` |
| `A5` | Steps <25% baseline dan wear time cukup | `WORSENED` | 4 | 1 hari → check context; multi-domain → escalate |
| `A6` | Steps <500, baseline >2.000, wear time ≥12 jam | `WORSENED` | 4 | Dapat `NEW_CONCERN` satu hari karena sangat tidak biasa |
| `A7` | Step rendah + `travel/illness/hospitalized/device_not_worn` | `MINOR_DEVIATION` / context | 0–1 | Jangan auto-escalate |
| `A8` | Steps turun ≥30% dari baseline selama ≥3 hari | `WORSENED` | 2 | `NEW_CONCERN` |
| `A9` | Steps turun ≥50% selama ≥2 hari + sleep buruk atau RHR naik | `WORSENED` | 4 | `ESCALATED_CONCERN` |
| `A10` | Walking speed turun 10–<15% vs baseline selama ≥3 hari | `MINOR_DEVIATION` | 1 | `OBSERVATION` |
| `A11` | Walking speed turun ≥15% vs baseline selama ≥3 hari | `WORSENED` | 2 | `NEW_CONCERN` |
| `A12` | `walking_steadiness_event = true` | `ACUTE_EVENT` / caution | 4 | High-priority policy; cek risiko jatuh |
| `A13` | `fall_event = true` | `ACUTE_EVENT` | 5 | `URGENT_OVERRIDE`, push segera |
| `A14` | Steps ≥85% baseline selama 3 hari setelah concern | `IMPROVED` | 0 | `IMPROVING` → `RESOLVED` |

### Checkpoint activity

| Checkpoint | Logika | Notifikasi |
|---|---|---|
| 12.00 | Bandingkan `steps_at_1200` dengan baseline steps jam 12.00 | Dashboard saja kecuali penurunan ekstrem + event lain |
| 18.00 | Bandingkan `steps_at_1800` dengan baseline steps jam 18.00 | Caution ringan jika <50% dan wear time cukup |
| 21.00 | Evaluasi total steps harian | Dasar utama daily condition dan frequency rule |

---

## 9. Rule catalog — Heart / recovery / safety (`H*`)

Heart rate tinggi tidak otomatis abnormal. Sistem harus mengecek konteks `workout_active`, workout terakhir, steps/cadence, dan apakah HR pulih setelah aktivitas.

| Rule ID | Kondisi | Daily condition | Severity | Frequency / outcome |
|---|---|---|---:|---|
| `H0` | RHR tidak tersedia | `NO_DATA` untuk RHR | 0 | Jangan menilai RHR |
| `H1` | RHR naik 5–<10 bpm dari baseline | `MINOR_DEVIATION` | 1 | ≥2 hari → `OBSERVATION` |
| `H2` | RHR naik ≥10 bpm dari baseline | `WORSENED` | 2 | ≥2–3 hari → `NEW_CONCERN` |
| `H3` | RHR naik ≥20 bpm dari baseline setelah quality/context check | `WORSENED` | 4 | 1 hari → `NEW_CONCERN`; multi-domain → escalate |
| `H4` | HRV turun ≥20% dari baseline | `MINOR_DEVIATION` | 1 | ≥3 hari + indikator lain → `OBSERVATION`/`NEW_CONCERN` |
| `H5` | HRV turun ≥30% + RHR naik ≥10 bpm | `WORSENED` | 3 | ≥2 hari → `NEW_CONCERN` |
| `H6` | RHR naik ≥10 bpm + HRV turun ≥20% + sleep worsened | `WORSENED` | 4 | ≥2 hari → `ESCALATED_CONCERN` |
| `H7` | HR tinggi ketika `workout_active=true` dan menurun ke arah pola biasa dalam 20–30 menit setelah workout | `ON_TRACK` | 0 | Tidak menjadi concern |
| `H8` | HR tetap tinggi >20–30 menit setelah workout atau tidak ada konteks aktivitas | `MINOR_DEVIATION` / `WORSENED` | 2 | Butuh definisi threshold HR personal; cek ulang dan observasi |
| `H9` | `high_hr_event = true` | `ACUTE_EVENT` | 5 | `URGENT_OVERRIDE` / priority push sesuai policy |
| `H10` | `low_hr_event = true` | `ACUTE_EVENT` | 5 | `URGENT_OVERRIDE` / priority push sesuai policy |
| `H11` | `irregular_rhythm_event = true` | `ACUTE_EVENT` | 5 | `URGENT_OVERRIDE` / priority push sesuai policy |
| `H12` | Respiratory rate berubah besar dari baseline selama ≥2 hari | `MINOR_DEVIATION` | 1 | Opsional; tidak diagnosis |
| `H13` | SpO₂ rendah/berubah dari baseline | `MINOR_DEVIATION` / context | 1–3 | Availability/device/region dependent; threshold klinis harus disetujui ahli |
| `H14` | RHR, HRV, dan sleep pulih selama 3 hari | `IMPROVED` | 0 | `IMPROVING` → `RESOLVED` |

### Safety override

`H9`, `H10`, `H11`, dan `A13` melewati frequency rule, baseline, dan cooldown. Mereka tidak boleh diputuskan atau dinarasikan oleh LLM sebelum policy safety/template tetap berjalan.

---

## 10. Priority resolver

Satu data dapat memicu beberapa rule. Sistem memilih severity tertinggi, menyimpan semua trigger, lalu membuat satu insight terintegrasi.

| Severity tertinggi | Daily condition final | Contoh |
|---:|---|---|
| 0 | `ON_TRACK` / `NO_DATA` | Steps stabil, RHR sesuai baseline |
| 1 | `MINOR_DEVIATION` | Tidur 6j30m atau RHR +6 bpm |
| 2 | `WORSENED` | Tidur <6 jam atau steps 60% baseline |
| 3 | `WORSENED` high | SE <75%, awake >90 menit, steps <50% baseline |
| 4 | `WORSENED` critical caution | Steps <25% baseline + wear time cukup; RHR +20 bpm; multi-domain |
| 5 | `ACUTE_EVENT` | Fall, irregular rhythm, high/low HR event Apple |

Pseudo-rule:

```text
final_daily_condition(domain) = condition_with_highest_severity(triggered_rules)
all_triggers = collect_all_triggered_rules()
```

---

## 11. Concern-state transition rules

| Current state | Input dari daily condition/rule | Next state | Catatan |
|---|---|---|---|
| `NONE` | Minor deviation satu kali | `OBSERVATION` | Tidak push |
| `NONE` | Pattern rule `S17`, `A3`, `H2`, dll terpenuhi | `NEW_CONCERN` | Push sekali jika action tersedia |
| `OBSERVATION` | Hari kembali on track 2–3 hari | `RESOLVED` | Lalu menjadi `NONE` |
| `OBSERVATION` | Rule frekuensi terpenuhi | `NEW_CONCERN` | Push pertama |
| `OBSERVATION` | Severity 4 atau multi-domain | `ESCALATED_CONCERN` | Push priority |
| `NEW_CONCERN` | Masalah tetap ada 3–7 hari, severity sama/tidak naik | `PERSISTENT_CONCERN` | Dashboard + weekly summary |
| `NEW_CONCERN` | Severity naik atau ada domain lain ikut memburuk | `ESCALATED_CONCERN` | Push baru |
| `NEW_CONCERN` | On track/improved 3 hari | `IMPROVING` | Tidak perlu push wajib |
| `PERSISTENT_CONCERN` | Deviasi besar dari baseline/severity naik | `ESCALATED_CONCERN` | Push baru meski cooldown |
| `PERSISTENT_CONCERN` | Improved 3–7 hari | `IMPROVING` | Tampilkan perbaikan |
| `IMPROVING` | On track 3–7 hari | `RESOLVED` | Concern selesai |
| `IMPROVING` | Trigger muncul lagi | `NEW_CONCERN` atau `ESCALATED_CONCERN` | Tergantung severity |
| Any state | Rule urgent (`A13`, `H9`, `H10`, `H11`) | `URGENT_OVERRIDE` | Push segera |

---

## 12. Overall care status

Overall status dihitung dari state tertinggi semua domain serta kombinasi multi-domain.

| Overall status | Kondisi | Delivery |
|---|---|---|
| `STABLE` | Semua domain on track; atau persistent baseline concern tanpa perburukan baru | Dashboard saja |
| `ATTENTION` | Ada observation/minor deviation | Kartu insight/ringkasan harian |
| `CAUTION` | Ada new concern atau high daily worsening | Push selektif + action check-in |
| `WARNING` | Escalated concern atau minimal dua domain memburuk beberapa hari | Push prioritas + cek kondisi/tensi bila tersedia |
| `URGENT` | Urgent override | Push segera + template tetap |

Contoh resolver:

```text
IF urgent_override exists:
    overall = URGENT
ELIF any domain is ESCALATED_CONCERN:
    overall = WARNING
ELIF number_of_domains_with_new_concern >= 2:
    overall = WARNING
ELIF any domain is NEW_CONCERN:
    overall = CAUTION
ELIF any domain is OBSERVATION:
    overall = ATTENTION
ELSE:
    overall = STABLE
```

---

## 13. Notification policy dan cooldown

| Kondisi | Notification policy |
|---|---|
| `ON_TRACK` / `IMPROVED` | Tidak ada push; tampilkan dashboard atau ringkasan positif opsional |
| `OBSERVATION` | Tidak ada push; masuk kartu daily insight |
| `NEW_CONCERN` | Push sekali per domain dalam 24 jam |
| `PERSISTENT_CONCERN` | Tidak ada push harian; ringkasan mingguan |
| `ESCALATED_CONCERN` | Push baru segera, meski concern yang sama pernah diberi tahu |
| `URGENT_OVERRIDE` | Push segera; cooldown tidak berlaku |
| Kondisi sama berulang | Cooldown 48–72 jam untuk push non-urgent; dashboard tetap diperbarui |
| Concern membaik | Ringkasan positif setelah 3–7 hari; jangan terlalu sering |

### Action catalog awal

| Status | Action yang diizinkan |
|---|---|
| `ATTENTION` | Pantau malam/hari berikutnya; lihat dashboard |
| `CAUTION` | Hubungi orang tua hari ini; tanyakan lemas, pusing, nyeri, sesak, demam; ingatkan ukur tensi bila tersedia |
| `WARNING` | Lakukan check-in segera; pastikan kondisi dan pengukuran tensi; pertimbangkan konsultasi bila pola berlanjut atau ada keluhan |
| `URGENT` | Gunakan template emergency policy; jangan gunakan LLM; cari bantuan sesuai protokol produk dan gejala |

---

## 14. Contoh evaluasi input 2026-08-22

### Input

| Domain | Nilai utama |
|---|---|
| Sleep | Total 400 menit (6j40m), time in bed 450 menit, awake 50 menit, SE 88,9%, deviation 0 menit |
| Activity | Steps 2.900 (101,8% baseline), steps 12.00 = 720, steps 18.00 = 2.500, walking speed +1,2%, wear time 21 jam |
| Heart | RHR 67, delta 0, HRV 30, HRV change 0, tidak ada event Apple/fall |

### Rule result

| Domain | Rule yang terpenuhi | Daily condition | Concern state | Interpretasi |
|---|---|---|---|---|
| Sleep | `S1` karena 400 menit = 6j40m | `MINOR_DEVIATION` absolut; `ON_TRACK` relatif jika sesuai baseline | `NONE` atau `OBSERVATION` jika berulang | Durasi sedikit di bawah target umum, tetapi kualitas dan jadwal baik |
| Activity | `A1` karena 101,8% baseline | `ON_TRACK` | `NONE` | Aktivitas sesuai pola pribadi |
| Heart | Tidak ada H1–H13 yang aktif | `ON_TRACK` | `NONE` | Indikator jantung sesuai baseline dan tidak ada event |
| Overall | Tidak ada concern signifikan | `STABLE` | — | Dashboard dapat menampilkan area sleep sebagai insight edukasi |

### Output yang aman

> **Kondisi hari ini relatif stabil.** Aktivitas dan indikator jantung berada dekat pola biasanya. Durasi tidur semalam sekitar 6 jam 40 menit—sedikit lebih pendek dari acuan umum lansia—tetapi jadwal dan efisiensi tidur relatif baik. Lanjutkan pemantauan pola tidur pada hari-hari berikutnya.

---

## 15. Contoh kasus state machine

### Case A — Baseline kurang ideal, tetapi stabil

Baseline 14 hari:

- Total tidur: 4 jam 20 menit.
- Sleep efficiency: 70%.
- Awake: 100 menit.

Hari ke-15:

- Total tidur: 4 jam 15 menit.
- Sleep efficiency: 69%.
- Awake: 105 menit.

| Layer | Output |
|---|---|
| Baseline profile | `PERSISTENT_CONCERN_BASELINE` |
| Daily condition | `ON_TRACK` relatif terhadap baseline; `BELOW_GENERAL_REFERENCE` absolut |
| Concern state | `PERSISTENT_CONCERN` |
| Notification | Tidak push harian; tampil di dashboard + weekly summary |

### Case B — Baseline kurang ideal lalu memburuk

Hari ke-20:

- Total tidur: 2 jam 40 menit.
- Sleep efficiency: 55%.
- Awake: 180 menit.
- RHR: +12 bpm dari baseline.

| Layer | Output |
|---|---|
| Sleep rules | `S3`, `S8`, `S11` |
| Heart rules | `H2` |
| Daily condition | `WORSENED` high |
| Concern state | `ESCALATED_CONCERN` |
| Overall | `WARNING` |
| Notification | Push caregiver + action check-in |

### Case C — HR tinggi saat workout, tetapi normal

- Workout walking aktif 20 menit.
- HR naik menjadi 122 bpm saat workout.
- Dalam 20 menit setelah selesai, HR turun ke 85 bpm.
- RHR harian tetap dekat baseline.

| Rule | Result |
|---|---|
| `H7` | Terpenuhi |
| Daily condition heart | `ON_TRACK` |
| Concern state heart | `NONE` |
| Notification | Tidak ada push |

---

## 16. Kontrak output untuk layer insight/LLM

Rule engine mengirim context terstruktur; LLM tidak boleh menentukan ulang kelas atau action.

```json
{
  "overall_status": "CAUTION",
  "concern_state": "NEW_CONCERN",
  "report_period": "3 hari terakhir",
  "triggered_rules": ["S17", "A8", "H2"],
  "facts": [
    "Total tidur kurang dari 6 jam selama 3 malam",
    "Langkah turun lebih dari 30% dari baseline selama 3 hari",
    "Resting heart rate meningkat 11 bpm dari baseline"
  ],
  "allowed_actions": [
    "Hubungi orang tua hari ini",
    "Tanyakan keluhan seperti lemas, pusing, nyeri, sesak, atau demam",
    "Ingatkan pengukuran tekanan darah dengan tensimeter bila tersedia"
  ],
  "prohibited_content": [
    "Diagnosis",
    "Penyebab pasti",
    "Mengubah dosis atau jadwal obat",
    "Angka baru di luar input",
    "Saran olahraga berat"
  ]
}
```

---

## 17. Test cases minimum

| ID | Skenario | Expected result |
|---|---|---|
| `TC-01` | Sleep 6j40m, SE 88,9%, stable | `MINOR_DEVIATION` absolut / on-track relatif; no push |
| `TC-02` | Sleep <6 jam dua malam berturut | `NEW_CONCERN` sleep; one push |
| `TC-03` | Sleep <5 jam dua kali/7 hari | High severity `NEW_CONCERN` |
| `TC-04` | Baseline sleep 4j20m, hari ini 4j15m | `ON_TRACK` relatif + persistent baseline concern; no daily push |
| `TC-05` | Baseline sleep 4j20m, hari ini 2j30m + SE 55% | `ESCALATED_CONCERN` |
| `TC-06` | Steps 45% baseline satu hari, wear time 21 jam | Worsened activity; observation/new concern depending extreme policy |
| `TC-07` | Steps <70% baseline tiga hari | `NEW_CONCERN` activity |
| `TC-08` | HR tinggi saat workout lalu pulih | `ON_TRACK`, no alert |
| `TC-09` | RHR +11 bpm selama tiga hari | `NEW_CONCERN` heart |
| `TC-10` | RHR +11, HRV -25%, sleep <6 jam dua hari | `ESCALATED_CONCERN`, overall warning |
| `TC-11` | Fall event true | `URGENT_OVERRIDE` immediately |
| `TC-12` | Irregular rhythm event true | `URGENT_OVERRIDE` immediately |
| `TC-13` | Data activity kosong, wear time 5 jam | `NO_DATA`, no clinical conclusion |

---

## 18. Batas klinis dan validasi

- Rule sleep/activity/heart ini adalah **rule early-caution product**, bukan guideline diagnosis.
- Threshold sleep duration, efficiency, variability, dan perubahan baseline dipakai untuk *screening signal* dan harus direview tenaga kesehatan sebelum uji lapangan.
- Heart rate dan HRV sangat personal; jangan memakai satu angka universal untuk memberi diagnosis.
- SpO₂ dan respiratory rate perlu kebijakan terpisah, karena ketersediaan/akurasi dapat dipengaruhi device, region, dan kondisi pemakaian.
- Data tensi harus dari tensimeter manset yang sesuai; Apple Watch tidak memberikan pembacaan SYS/DIA langsung.
- Event Apple Watch tetap memerlukan evaluasi gejala dan kebijakan keselamatan yang jelas.

---

## 19. Ringkasan implementasi

```text
1. Simpan raw records dari HealthKit.
2. Bentuk daily features per domain.
3. Setelah 14 hari/10 hari valid, bangun baseline personal.
4. Jalankan rule S*, A*, dan H* pada waktu evaluasi masing-masing.
5. Tentukan daily condition dari severity tertinggi.
6. Jalankan state-machine untuk mengubah concern state.
7. Hitung overall care status.
8. Terapkan cooldown dan notification policy.
9. Buat insight memakai template atau LLM dari context yang sudah ditentukan rule engine.
10. Simpan audit trail: raw values → rules → daily condition → concern state → notification.
```
