# PRD — Early Caution Caregiver untuk Lansia Berbasis Apple Health / Apple Watch

**Status:** Draft teknis / MVP  
**Target pengguna:** Anak atau keluarga yang memantau orang tua/lansia dari jarak jauh  
**Platform awal:** iOS + Apple Health/HealthKit + backend API + dashboard caregiver  
**Fokus:** Sleep, activity, heart/recovery, event keselamatan, dan integrasi tekanan darah opsional dari tensimeter manset.  
**Batas produk:** Ini adalah sistem *early caution* dan *caregiver decision support*, **bukan alat diagnosis, alat penentu terapi, maupun layanan kegawatdaruratan**.

---

## 1. Ringkasan produk

Aplikasi mengambil data kesehatan dan perilaku dari iPhone/Apple Watch melalui Apple Health/HealthKit. Sistem mengolah data menjadi fitur harian, membangun baseline personal, dan mendeteksi perubahan pola yang relevan bagi caregiver.

Output utama aplikasi adalah **Daily Care Signal**:

- **Stabil** — pola hari ini sesuai kebiasaan orang tua.
- **Perlu diperhatikan** — terdapat perubahan ringan atau pola awal.
- **Caution** — perubahan bermakna/berulang; anak perlu melakukan check-in.
- **Warning** — perubahan memburuk dan/atau didukung data tensi/gejala/event penting.
- **Urgent** — event keselamatan atau sinyal medis penting; gunakan template tetap dan tindakan segera sesuai kebijakan produk.

Produk tidak mengatakan “orang tua pasti sakit” atau “tensi naik karena tidur kurang”. Produk memakai bahasa: **“dapat berkaitan dengan”**, **“dapat berkontribusi”**, dan **“perlu dilakukan check-in”**.

---

## 2. Masalah yang diselesaikan

Anak/caregiver sering tidak melihat perubahan kecil yang terjadi pada orang tua, misalnya:

- Tidur menjadi lebih pendek dan lebih sering terputus.
- Aktivitas harian turun tajam dibanding kebiasaan.
- Resting heart rate meningkat beberapa hari.
- Jadwal tidur berubah jauh dari pola pribadi.
- Ada Fall Detection atau irregular rhythm notification dari Apple Watch.
- Data tensi dari tensimeter menunjukkan kenaikan dibanding pola sebelumnya.

Satu metrik saja sering tidak cukup untuk menarik kesimpulan. Sistem perlu melihat **baseline personal + perubahan harian + frekuensi + konteks aktivitas** agar caregiver menerima notifikasi yang bermakna tanpa spam.

---

## 3. Goals dan non-goals

### Goals

1. Menarik data HealthKit dengan izin pengguna.
2. Menampilkan dashboard monitoring yang *near-real-time* sesuai data yang tersinkron.
3. Membentuk baseline personal dari data 14 hari.
4. Menghasilkan kondisi harian per domain: sleep, activity, heart, dan safety.
5. Menyimpan concern secara longitudinal: baru, menetap, memburuk, membaik, selesai.
6. Mengirim notifikasi ke caregiver hanya bila actionable.
7. Menghasilkan ringkasan Bahasa Indonesia yang aman menggunakan template atau LLM terbatasi.
8. Mendukung data tensi manual/BLE sebagai sumber mmHg yang terpisah dari Apple Watch.

### Non-goals MVP

1. Mendiagnosis hipertensi, insomnia, sleep apnea, penyakit jantung, atau depresi.
2. Mengukur tekanan darah mmHg dari Apple Watch.
3. Mengubah dosis/jadwal obat otomatis.
4. Memberi rekomendasi workout intensitas tinggi berdasarkan score.
5. Menjadi sistem emergency dispatch atau pengganti dokter/IGD.
6. Melatih foundation model medis sendiri.

---

## 4. Arsitektur konseptual

```text
Apple Watch / iPhone
        |
        v
Apple Health / HealthKit
        |
        v
Mobile app (permission + sync)
        |
        v
Backend ingestion API
        |
        v
Data quality checks
        |
        v
Feature engineering
        |
        +--------------------------+
        |                          |
        v                          v
Baseline service             Rule engine
        |                          |
        +-----------> State machine+
                                      |
                                      v
                         Notification policy / cooldown
                                      |
                          +-----------+-----------+
                          |                       |
                          v                       v
                Template renderer          LLM summary layer
                          |                       |
                          +-----------> Dashboard / Push
```

### Prinsip arsitektur

- **Rule engine adalah sumber kebenaran** untuk kelas, trigger, urgensi, dan action.
- **State machine** mengelola concern lintas hari, bukan LLM.
- **LLM hanya menulis narasi** berdasarkan fakta terstruktur, tindakan yang diizinkan, dan batasan keselamatan.
- Untuk `URGENT`, gunakan **template tetap tanpa LLM**.
- Jika output LLM gagal validasi, sistem memakai **template fallback**.

---

## 5. Data domain

### 5.1 Sleep

| Field | Tipe | Sumber / cara hitung | Contoh |
|---|---|---|---|
| `bedtime` | datetime | HealthKit sleep interval | `2026-09-06T22:45:00+07:00` |
| `wake_time` | datetime | HealthKit sleep interval | `2026-09-07T06:10:00+07:00` |
| `total_sleep_minutes` | integer | Core + Deep + REM | `395` |
| `time_in_bed_minutes` | integer | in-bed duration atau wake - bedtime | `445` |
| `awake_minutes` | integer | total Awake interval | `50` |
| `sleep_efficiency_pct` | float | total sleep / time in bed × 100 | `88.8` |
| `rem_minutes` | integer | HealthKit | `90` |
| `core_minutes` | integer | HealthKit | `235` |
| `deep_minutes` | integer | HealthKit | `70` |
| `bedtime_deviation_minutes` | integer | vs baseline personal | `35` |
| `wake_time_deviation_minutes` | integer | vs baseline personal | `20` |
| `sleep_duration_deviation_minutes` | integer | vs baseline personal | `-60` |
| `bedtime_sd_7d_minutes` | float | SD 7 hari | `42.0` |

### 5.2 Activity dan mobility

| Field | Tipe | Sumber / cara hitung | Contoh |
|---|---|---|---|
| `steps` | integer | HealthKit `stepCount` | `1400` |
| `steps_pct_of_baseline` | float | steps / baseline steps × 100 | `46.7` |
| `steps_at_1200` | integer | snapshot waktu | `450` |
| `steps_at_1800` | integer | snapshot waktu | `1100` |
| `exercise_minutes` | integer | Apple Exercise Time/workout | `12` |
| `walking_distance_km` | float | walking/running distance | `0.9` |
| `walking_speed_mps` | float | HealthKit mobility | `0.78` |
| `walking_speed_pct_change` | float | vs baseline | `-14` |
| `walking_steadiness_event` | boolean/category | Apple walking steadiness | `false` |
| `workout_active` | boolean | active workout session | `true` |
| `workout_type` | string/enum | workout record | `walking` |
| `watch_wear_hours` | float | quality heuristic | `20.5` |

### 5.3 Heart, recovery, dan safety

| Field | Tipe | Sumber / cara hitung | Contoh |
|---|---|---|---|
| `heart_rate_current_bpm` | float | HealthKit heart rate sample | `84` |
| `resting_hr_bpm` | float | HealthKit resting HR | `78` |
| `resting_hr_delta_bpm` | float | vs baseline | `12` |
| `walking_hr_avg_bpm` | float | HealthKit walking HR average | `98` |
| `hrv_sdnn_ms` | float | HealthKit HRV SDNN | `19` |
| `hrv_pct_change` | float | vs baseline | `-27` |
| `respiratory_rate` | float | optional | `16.5` |
| `oxygen_saturation_pct` | float | optional/availability dependent | `97.0` |
| `high_hr_event` | boolean | Apple Watch notification event | `false` |
| `low_hr_event` | boolean | Apple Watch notification event | `false` |
| `irregular_rhythm_event` | boolean | HealthKit category event | `false` |
| `fall_event` | boolean | Fall Detection event | `false` |

### 5.4 Tekanan darah dan konteks manual

| Field | Tipe | Catatan |
|---|---|---|
| `bp_systolic` | integer/null | Dari tensimeter manset, bukan Apple Watch |
| `bp_diastolic` | integer/null | Dari tensimeter manset, bukan Apple Watch |
| `bp_measurement_time` | datetime/null | Untuk pagi/malam dan tren |
| `medication_taken` | boolean/null | Konfirmasi pasien/caregiver |
| `symptoms` | array[string] | Mis. `pusing`, `sesak`, `nyeri_dada` |
| `side_effects` | array[string] | Dilaporkan pengguna |
| `context_tags` | array[enum] | `travel`, `illness`, `hospitalized`, `workout`, `device_not_worn` |

---

## 6. Baseline profile

### 6.1 Masa pembentukan baseline

- Periode awal: **14 hari**.
- Syarat baseline aktif: minimal **10 hari data valid** dari 14 hari.
- Hari dengan data sangat tidak lengkap, perjalanan, rawat inap, atau kondisi akut dapat ditandai untuk tidak ikut baseline.
- Gunakan **median**, bukan rata-rata, agar satu hari ekstrem tidak merusak baseline.
- Gunakan IQR atau standard deviation untuk menggambarkan variasi normal personal.
- Setelah baseline aktif, perbarui secara **mingguan** memakai rolling window 14–28 hari.
- Jangan memasukkan hari `ESCALATED_CONCERN`, `URGENT_OVERRIDE`, atau konteks sakit akut ke baseline baru secara otomatis.

### 6.2 Baseline per metrik

```json
{
  "baseline_id": "base_parent_001_2026w37",
  "user_id": "PARENT_001",
  "period_days": 14,
  "valid_days": 12,
  "sleep": {
    "median_total_sleep_minutes": 395,
    "median_bedtime": "22:45",
    "median_wake_time": "06:10",
    "median_sleep_efficiency_pct": 87.8,
    "median_awake_minutes": 55,
    "bedtime_sd_minutes": 25,
    "sleep_duration_sd_minutes": 35
  },
  "activity": {
    "median_steps_daily": 2850,
    "median_steps_at_1200": 700,
    "median_steps_at_1800": 2450,
    "median_walking_speed_mps": 0.83
  },
  "heart": {
    "median_resting_hr_bpm": 68,
    "resting_hr_iqr_bpm": 5,
    "median_hrv_sdnn_ms": 29
  }
}
```

### 6.3 Kelas baseline profile

| Kode | Label UI | Definisi |
|---|---|---|
| `INSUFFICIENT_DATA` | Data belum cukup | <10 hari data valid atau data terlalu banyak kosong |
| `FAVORABLE_BASELINE` | Pola dasar relatif baik | Mayoritas indikator stabil dan mendekati acuan umum |
| `STABLE_WITH_NEEDS` | Pola dasar stabil, perlu dukungan | Ada indikator kurang optimal, tetapi stabil |
| `PERSISTENT_CONCERN_BASELINE` | Pola dasar perlu perhatian | Masalah berulang sejak onboarding, mis. tidur <6 jam atau SE rendah pada banyak malam |
| `UNSTABLE_BASELINE` | Pola dasar belum stabil | Variasi tinggi, konteks berubah, atau baseline belum representatif |
| `CONTEXT_REQUIRED` | Butuh konteks | Perjalanan, shift, sakit, atau pola tidur utama siang hari |

**Penting:** baseline yang kurang baik bukan “normal sehat”. Ia dipakai untuk membedakan masalah yang **stabil** dari masalah yang **makin buruk**.

---

## 7. Daily condition

Daily condition adalah snapshot domain **hari ini**. Ia memiliki dua dimensi:

1. `relative_status`: dibanding baseline pribadi.
2. `absolute_status`: dibanding acuan umum bila tersedia.

Contoh: tidur 4 jam 15 menit ketika baseline 4 jam 20 menit → `ON_TRACK` relatif, tetapi `BELOW_GENERAL_REFERENCE` secara absolut.

| Kode daily condition | Label UI | Makna |
|---|---|---|
| `NO_DATA` | Data belum tersedia | Data kurang/tidak valid/watch tidak dipakai |
| `ON_TRACK` | Stabil dibanding pola biasa | Mendekati baseline dan tidak ada perubahan bermakna |
| `IMPROVED` | Lebih baik dari pola biasa | Perbaikan bermakna dibanding baseline/concern sebelumnya |
| `MINOR_DEVIATION` | Ada perubahan ringan | Berubah ringan dan belum membentuk pola |
| `WORSENED` | Kondisi memburuk hari ini | Deviasi besar atau threshold harian kuat |
| `ACUTE_EVENT` | Perlu dicek segera | Event keselamatan atau event Apple resmi; baseline tidak relevan |

### Jadwal evaluasi daily condition

| Domain | Evaluasi | Catatan |
|---|---|---|
| Sleep | Setelah tidur utama selesai, biasanya pagi | Data total tidur baru lengkap setelah bangun |
| Activity | Dashboard live + checkpoint 12.00, 18.00, final 21.00 | Bandingkan dengan baseline pada waktu yang sama |
| Heart rate live | Saat data tersedia | Informasi kontekstual; jangan interpretasi HR tinggi tanpa activity/workout context |
| Resting HR / HRV | Harian | Lebih valid sebagai tren harian, bukan per menit |
| Workout | Saat sesi selesai | HR tinggi saat workout dapat normal bila pulih |
| Fall/irregular rhythm/high-low HR event | Event-driven | Diproses segera |
| Blood pressure | Saat hasil tensimeter masuk | Diproses segera; gunakan flow pengukuran ulang bila tinggi |

---

## 8. Concern state dan state machine

### 8.1 Definisi sederhana

- **Daily condition:** “Hari ini seperti apa?”
- **Concern state:** “Masalah ini baru, menetap, memburuk, membaik, atau selesai?”
- **State machine:** aturan perpindahan concern state berdasarkan daily condition, frekuensi, severity, dan event.

Concern state dibuat **per domain**:

```json
{
  "sleep_concern_state": "PERSISTENT_CONCERN",
  "activity_concern_state": "NONE",
  "heart_concern_state": "OBSERVATION",
  "overall_care_status": "CAUTION"
}
```

### 8.2 Kelas concern state

| Kode | Label UI | Definisi | Notifikasi |
|---|---|---|---|
| `NONE` | Tidak ada concern aktif | Tidak ada masalah aktif | Tidak ada push |
| `OBSERVATION` | Sedang dipantau | Satu deviasi ringan; belum cukup menjadi pola | Dashboard saja |
| `NEW_CONCERN` | Perubahan baru terdeteksi | Threshold/pattern pertama kali terpenuhi | Push sekali bila actionable |
| `PERSISTENT_CONCERN` | Pola masih perlu perhatian | Masalah tetap ada, tetapi tidak memburuk | Dashboard + ringkasan mingguan |
| `ESCALATED_CONCERN` | Kondisi memburuk | Severity meningkat, deviasi besar, atau multi-domain concern | Push baru ke caregiver |
| `IMPROVING` | Kondisi mulai membaik | Perbaikan konsisten 3–7 hari | Ringkasan positif opsional |
| `RESOLVED` | Kembali stabil | Tidak lagi memenuhi trigger recovery period | Tidak ada push |
| `URGENT_OVERRIDE` | Perlu dicek segera | Fall, event heart Apple, tensi/gejala berisiko | Push segera/template tetap |

### 8.3 Transisi state machine

```text
NONE
  └─ minor deviation 1x → OBSERVATION

OBSERVATION
  ├─ pulih → RESOLVED → NONE
  ├─ rule frekuensi terpenuhi → NEW_CONCERN
  └─ makin berat → ESCALATED_CONCERN

NEW_CONCERN
  ├─ menetap tanpa perburukan → PERSISTENT_CONCERN
  ├─ memburuk / multi-domain → ESCALATED_CONCERN
  └─ membaik beberapa hari → IMPROVING

PERSISTENT_CONCERN
  ├─ memburuk → ESCALATED_CONCERN
  └─ membaik 3–7 hari → IMPROVING

IMPROVING
  ├─ stabil pulih → RESOLVED → NONE
  └─ trigger muncul lagi → NEW_CONCERN atau ESCALATED_CONCERN

ANY STATE
  └─ critical event → URGENT_OVERRIDE
```

---

## 9. Rule engine MVP

### 9.1 Prinsip rule

1. Gunakan baseline personal untuk perubahan relatif.
2. Gunakan standar populasi sebagai informasi absolut.
3. Jangan membuat satu metrik menjadi diagnosis.
4. Butuh frekuensi/persistensi untuk non-urgent alert.
5. Event keselamatan dan event Apple resmi mengabaikan baseline/cooldown.
6. Ambil severity tertinggi; jangan mengirim satu push untuk setiap rule.

### 9.2 Sleep rules

| Rule ID | Kondisi | Daily condition | Pattern / frekuensi | Concern outcome |
|---|---|---|---|---|
| `SLEEP_NO_DATA` | sleep record tidak valid | `NO_DATA` | — | — |
| `SLEEP_SHORT_MILD` | total sleep 6–<7 jam | `MINOR_DEVIATION` | ≥3 malam/7 hari | `OBSERVATION` atau `NEW_CONCERN` |
| `SLEEP_SHORT` | total sleep <6 jam | `WORSENED` | ≥2 malam berturut-turut atau ≥3 malam/7 hari | `NEW_CONCERN` |
| `SLEEP_VERY_SHORT` | total sleep ≤5 jam | `WORSENED` high severity | ≥2 malam/7 hari | `NEW_CONCERN` severity tinggi |
| `SLEEP_LONG` | total sleep >9 jam | `MINOR_DEVIATION` | ≥3 malam/7 hari | `NEW_CONCERN`; minta konteks |
| `SLEEP_SE_LOW` | SE 80–<85% | `MINOR_DEVIATION` | ≥3 malam/7 hari | `OBSERVATION` |
| `SLEEP_SE_POOR` | SE 75–<80% | `WORSENED` | ≥2 malam berturut atau ≥3 malam/7 hari | `NEW_CONCERN` |
| `SLEEP_SE_VERY_POOR` | SE <75% | `WORSENED` high severity | ≥2 malam/7 hari | `NEW_CONCERN` severity tinggi |
| `SLEEP_AWAKE_HIGH` | Awake >60 menit | `WORSENED` | ≥3 malam/7 hari | `NEW_CONCERN` |
| `SLEEP_TIMING_SHIFT` | bedtime deviation >60 menit | `WORSENED` | ≥2 malam/7 hari | `NEW_CONCERN` |
| `SLEEP_TIMING_EXTREME` | bedtime/midpoint deviation >120 menit | `WORSENED` high severity | 1x minta konteks; ≥2x/7 hari escalate | `NEW_CONCERN` / `ESCALATED_CONCERN` |
| `SLEEP_IRREGULAR` | bedtime SD 7 hari >60 menit | `WORSENED` | complete 7-day window | `NEW_CONCERN` |
| `SLEEP_BP_COMBINED` | sleep concern + BP pagi meningkat dari baseline | `WORSENED` | ≥2–3 hari | `ESCALATED_CONCERN` |

### 9.3 Activity rules

| Rule ID | Kondisi | Daily condition | Pattern / frekuensi | Concern outcome |
|---|---|---|---|---|
| `ACTIVITY_NO_DATA` | wear time tidak cukup atau data hilang | `NO_DATA` | — | — |
| `ACTIVITY_MINOR_LOW` | steps 70–<85% baseline pada akhir hari | `MINOR_DEVIATION` | 1 hari | `OBSERVATION` |
| `ACTIVITY_LOW` | steps 50–<70% baseline | `WORSENED` | ≥3 hari/7 hari | `NEW_CONCERN` |
| `ACTIVITY_VERY_LOW` | steps <50% baseline | `WORSENED` high severity | ≥2 hari berturut | `NEW_CONCERN` |
| `ACTIVITY_EXTREME_DROP` | steps <25% baseline + wear time cukup | `WORSENED` high severity | 1 hari; cek konteks | `NEW_CONCERN` / escalate bila multi-domain |
| `ACTIVITY_WALK_SLOW` | walking speed turun ≥10–15% | `WORSENED` | ≥3 hari/7 hari | `NEW_CONCERN` |
| `ACTIVITY_STEADINESS` | reduced walking steadiness event | `ACUTE_EVENT` / caution | event baru | `URGENT_OVERRIDE` atau high caution policy |
| `ACTIVITY_FALL` | fall event | `ACUTE_EVENT` | 1x | `URGENT_OVERRIDE` |
| `ACTIVITY_MULTI_DOMAIN` | steps turun ≥50% + RHR naik / sleep buruk | `WORSENED` | ≥2 hari | `ESCALATED_CONCERN` |

### 9.4 Heart rules

| Rule ID | Kondisi | Daily condition | Pattern / frekuensi | Concern outcome |
|---|---|---|---|---|
| `HEART_RHR_MINOR` | RHR naik 5–<10 bpm vs baseline | `MINOR_DEVIATION` | ≥2 hari | `OBSERVATION` |
| `HEART_RHR_HIGH` | RHR naik ≥10 bpm vs baseline | `WORSENED` | ≥2–3 hari | `NEW_CONCERN` |
| `HEART_RHR_EXTREME` | RHR naik ≥20 bpm vs baseline setelah quality/context check | `WORSENED` high severity | 1 hari | `NEW_CONCERN` / escalate bila multi-domain |
| `HEART_HRV_LOW` | HRV turun ≥20% vs baseline | `MINOR_DEVIATION` | ≥3 hari dan indikator lain mendukung | `OBSERVATION` / `NEW_CONCERN` |
| `HEART_RECOVERY` | RHR naik + HRV turun + sleep buruk | `WORSENED` | ≥2 hari | `ESCALATED_CONCERN` |
| `HEART_WORKOUT_CONTEXT` | HR tinggi saat workout dan pulih setelah selesai | `ON_TRACK` | — | `NONE` |
| `HEART_ALERT` | high/low HR event Apple | `ACUTE_EVENT` | 1x | `URGENT_OVERRIDE` / priority policy |
| `HEART_IRREGULAR` | irregular rhythm event Apple | `ACUTE_EVENT` | 1x | `URGENT_OVERRIDE` / priority policy |

### 9.5 Blood-pressure rules (opsional, jika ada tensimeter)

| Rule ID | Kondisi | Aksi sistem |
|---|---|---|
| `BP_MISSING` | Tidak ada tensi | Jangan menyimpulkan BP dari Apple Watch |
| `BP_RISING_TREND` | SBP/DBP meningkat bermakna dari baseline selama ≥2–3 hari | Tambahkan konteks ke warning terintegrasi |
| `BP_HIGH_REPEAT` | Hasil tinggi berulang sesuai policy klinis yang disetujui ahli | Minta pengukuran ulang dan pertimbangkan konsultasi |
| `BP_URGENT` | Hasil sangat tinggi dan/atau gejala red flag | Template urgent; jangan gunakan LLM |

Threshold BP final harus dikonfirmasi dengan dokter/pedoman lokal dan flow produk harus memasukkan pengukuran ulang serta gejala. Apple Watch bukan sumber pembacaan SYS/DIA.

---

## 10. Overall Care Status

Overall status dihitung dari severity tertinggi, kombinasi domain, dan urgent override.

| Overall status | Contoh logika | Delivery |
|---|---|---|
| `STABLE` | Semua domain `ON_TRACK`, atau concern persistent namun tidak ada perburukan baru | Dashboard saja |
| `ATTENTION` | Satu `MINOR_DEVIATION`, atau satu `OBSERVATION` | Kartu insight / ringkasan harian |
| `CAUTION` | Satu `NEW_CONCERN`, satu condition berat, atau dua domain minor memburuk | Push selektif + check-in action |
| `WARNING` | `ESCALATED_CONCERN`, sleep/activity/heart memburuk bersama, atau BP trend meningkat | Push prioritas + tindakan terarah |
| `URGENT` | `URGENT_OVERRIDE`, event keselamatan/jantung, BP/gejala sesuai emergency policy | Push segera + template tetap |

## 11. Notification policy

| Kejadian | Kanal | Aturan anti-spam |
|---|---|---|
| Daily sleep result | Dashboard | Tidak perlu push untuk perubahan ringan 1 malam |
| New concern | Push caregiver | Maksimal 1 push/domain/24 jam |
| Persistent concern | Dashboard + weekly summary | Jangan push harian |
| Escalated concern | Push segera | Abaikan cooldown jika severity naik atau domain baru muncul |
| Improving | Dashboard / weekly summary | Push positif opsional |
| Urgent override | Push segera | Tidak memakai cooldown |
| No data | Dashboard | Jangan anggap sebagai kondisi sehat |

### Waktu proses

- **Sleep:** evaluasi setelah tidur utama selesai, biasanya pagi.
- **Activity:** tampil *near-real-time*, tetapi evaluasi meaningful pada checkpoint 12.00, 18.00, dan akhir hari.
- **Heart:** HR live hanya data informasi; RHR/HRV dievaluasi harian. Event Apple diproses event-driven.
- **Daily Care Signal:** ringkasan maksimal 1x/hari, misalnya 20.00–21.00, ditambah ringkasan sleep pagi.

---

## 12. LLM layer

### 12.1 Kapan LLM dipakai

| Status | Renderer yang dipakai |
|---|---|
| `STABLE` | Template |
| `ATTENTION` | Template atau LLM |
| `CAUTION` | LLM dengan structured input + validator |
| `WARNING` | Template terkontrol; LLM hanya opsional untuk penjelasan non-kritis |
| `URGENT` | Template tetap tanpa LLM |

### 12.2 Input LLM

```json
{
  "task": "generate_caregiver_insight",
  "language": "id-ID",
  "audience": "anak/caregiver lansia",
  "parent_display_name": "Ibu",
  "overall_status": "CAUTION",
  "concern_state": "NEW_CONCERN",
  "report_period": "3 hari terakhir",
  "facts": [
    "Total tidur kurang dari 6 jam selama 3 malam",
    "Langkah berada 52% di bawah baseline selama 3 hari",
    "Resting heart rate meningkat 11 bpm dari baseline"
  ],
  "allowed_actions": [
    "Hubungi orang tua hari ini",
    "Tanyakan keluhan seperti lemas, pusing, nyeri, sesak, atau demam",
    "Ingatkan pengukuran tekanan darah dengan tensimeter bila tersedia"
  ],
  "prohibited_content": [
    "Diagnosis penyakit",
    "Penyebab pasti",
    "Perubahan dosis atau jadwal obat",
    "Angka atau fakta di luar input",
    "Saran olahraga berat"
  ],
  "style": {
    "tone": "tenang, empatik, ringkas",
    "max_sentences": 4
  }
}
```

### 12.3 Output LLM yang wajib tervalidasi

```json
{
  "title": "Perubahan pola perlu diperhatikan",
  "summary": "Dalam tiga hari terakhir, tidur Ibu lebih pendek dari pola biasanya, aktivitas harian berkurang, dan denyut saat istirahat meningkat. Perubahan ini dapat terjadi saat tubuh kurang pulih atau sedang tidak enak badan, tetapi tidak menunjukkan penyebab pasti.",
  "recommended_actions": [
    "Hubungi Ibu hari ini dan tanyakan keluhan.",
    "Jika tersedia, bantu ukur tekanan darah dengan tensimeter."
  ],
  "urgency": "CAUTION"
}
```

### 12.4 Validator output LLM

1. `urgency` harus sama dengan output rule engine.
2. Semua action harus berasal dari `allowed_actions` atau template yang sudah disetujui.
3. Tolak output yang mengandung diagnosis, sebab-akibat pasti, dosis obat, atau angka baru.
4. Tolak jika ada instruksi emergency yang tidak berasal dari engine.
5. Jika gagal, gunakan template fallback.

---

## 13. Struktur folder iOS (Arterious)

Struktur folder berikut mencerminkan project Xcode aktual dengan arsitektur MVVM. Semua data model (termasuk LLM schema) disimpan di `Models/` root agar satu sumber kebenaran. `LLMIntegration/` hanya berisi mock data, services, ViewModel, dan View.

```text
Arterious/                              # Xcode project root
├── Arterious.xcodeproj/
│
├── Arterious/                          # Main target source
│   ├── ArteriousApp.swift              # @main App entry point
│   ├── ContentView.swift               # Root TabView
│   ├── Arterious.entitlements          # HealthKit entitlements
│   │
│   ├── Assets.xcassets/                # App icons, colors, images
│   │
│   ├── Components/                     # Reusable UI components
│   │   ├── CautionCardView.swift
│   │   └── MetricCardView.swift
│   │
│   ├── Models/                         # Semua data model (shared)
│   │   ├── HealthModels.swift          # MetricType, WellnessStatus, DailyHealthSummary, dll
│   │   ├── LLMInsightInput.swift       # Structured input → LLM (§12.2)
│   │   ├── LLMInsightOutput.swift      # Validated output ← LLM (§12.3)
│   │   └── OverallCareStatus.swift     # STABLE, ATTENTION, CAUTION, WARNING, URGENT
│   │
│   ├── Services/                       # Service layer
│   │   └── HealthKitManager.swift      # HealthKit queries & mock history
│   │
│   ├── ViewModels/                     # ViewModels
│   │   └── DashboardViewModel.swift    # Dashboard logic, baseline, caution detection
│   │
│   ├── Views/                          # Feature views
│   │   └── Dashboard/
│   │       └── DashboardView.swift
│   │
│   ├── LLMIntegration/                 # Gemini LLM tech proof module
│   │   │
│   │   ├── MockData/                   # Data dummy / skenario sintetis (§18.3)
│   │   │   └── MockHealthScenarios.swift
│   │   │
│   │   ├── Services/                   # LLM service layer
│   │   │   ├── LLMServiceProtocol.swift      # Protocol generateInsight()
│   │   │   ├── GeminiLLMService.swift         # Hit Gemini API (direct Gemini REST)
│   │   │   ├── LLMOutputValidator.swift       # Guardrail validator (§12.4 & §17)
│   │   │   └── FallbackTemplateService.swift  # Template fallback bahasa Indonesia
│   │   │
│   │   ├── ViewModels/                 # ViewModel untuk tech proof
│   │   │   └── LLMProofViewModel.swift
│   │   │
│   │   └── Views/                      # UI tech proof
│   │       └── LLMProofView.swift
│   │
│   ├── Configuration/                  # Environment & API config
│   │   └── APIConfig.swift             # ★ Hardcode API key Gemini di sini
│   │
│   └── docs/                           # Dokumentasi produk
│       └── PRD_Early_Caution_Caregiver_Apple_Health.md
│
└── Arterious.xcodeproj/
```

### Catatan struktur

- **Semua data model ada di `Models/` root**, termasuk schema LLM (`LLMInsightInput`, `LLMInsightOutput`, `OverallCareStatus`). Tidak ada model terpisah di `LLMIntegration/`.
- **`LLMIntegration/`** hanya berisi MockData, Services, ViewModels, dan Views.
- **`Configuration/APIConfig.swift`** tempat hardcode API key Gemini. Cukup ganti value string-nya di file ini.
- **`docs/`** menyimpan PRD dan dokumentasi produk lainnya.
- **`MockData/`** berisi data dummy yang akan dilempar ke LLM sesuai skenario evaluasi PRD §18.3.

---

## 14. Tanggung jawab folder iOS

| Folder | Tanggung jawab | Contoh |
|---|---|---|
| `Components/` | Komponen UI reusable lintas fitur | `CautionCardView`, `MetricCardView` |
| `Models/` | Semua data model dan enum (termasuk LLM schema) | `HealthModels`, `LLMInsightInput`, `LLMInsightOutput`, `OverallCareStatus` |
| `Services/` | Akses data dan business logic layer | `HealthKitManager` — query HealthKit, generate mock |
| `ViewModels/` | State management dan logika presentasi | `DashboardViewModel` — baseline, caution detection |
| `Views/` | Layar utama per fitur | `DashboardView` |
| `Configuration/` | API key (hardcode), base URL, environment | `APIConfig` — tempat paste API key Gemini |
| `LLMIntegration/MockData/` | Data dummy skenario sintetis | Skenario dari §18.3 untuk test tanpa HealthKit |
| `LLMIntegration/Services/` | Service hit Gemini API + validator + fallback | `GeminiLLMService`, `LLMOutputValidator`, `FallbackTemplateService` |
| `LLMIntegration/ViewModels/` | ViewModel tech proof LLM | `LLMProofViewModel` — orchestrate scenario → API → validate |
| `LLMIntegration/Views/` | UI interaktif tech proof | `LLMProofView` — scenario picker, API config, result card |
| `docs/` | Dokumentasi produk | PRD, architecture docs |

---

## 15. Data model inti

### 15.1 Raw health sample

```json
{
  "sample_id": "hk_abc123",
  "user_id": "PARENT_001",
  "source": "apple_healthkit",
  "metric": "heart_rate",
  "value": 84,
  "unit": "bpm",
  "start_at": "2026-09-06T10:20:00+07:00",
  "end_at": "2026-09-06T10:20:00+07:00",
  "metadata": {
    "workout_active": false,
    "device": "Apple Watch"
  }
}
```

### 15.2 Daily feature record

```json
{
  "user_id": "PARENT_001",
  "date": "2026-09-06",
  "sleep": {
    "total_sleep_minutes": 320,
    "time_in_bed_minutes": 420,
    "sleep_efficiency_pct": 76.2,
    "awake_minutes": 100,
    "bedtime_deviation_minutes": 95,
    "sleep_duration_deviation_minutes": -110
  },
  "activity": {
    "steps": 1400,
    "steps_pct_of_baseline": 46.7,
    "walking_speed_pct_change": -14,
    "watch_wear_hours": 20.5
  },
  "heart": {
    "resting_hr_bpm": 78,
    "resting_hr_delta_bpm": 12,
    "hrv_sdnn_ms": 19,
    "hrv_pct_change": -27,
    "fall_event": false,
    "irregular_rhythm_event": false
  },
  "blood_pressure": {
    "systolic": null,
    "diastolic": null
  }
}
```

### 15.3 Rule evaluation result

```json
{
  "user_id": "PARENT_001",
  "date": "2026-09-06",
  "domain": "sleep",
  "daily_condition": "WORSENED",
  "absolute_status": "BELOW_GENERAL_REFERENCE",
  "triggered_rules": [
    "SLEEP_SHORT",
    "SLEEP_SE_POOR",
    "SLEEP_TIMING_SHIFT"
  ],
  "severity": 2,
  "recommended_actions": [
    "Hubungi orang tua hari ini",
    "Tanyakan keluhan",
    "Ingatkan pengukuran tekanan darah bila tersedia"
  ]
}
```

### 15.4 Concern state record

```json
{
  "user_id": "PARENT_001",
  "domain": "sleep",
  "state": "ESCALATED_CONCERN",
  "entered_at": "2026-09-06T08:00:00+07:00",
  "previous_state": "PERSISTENT_CONCERN",
  "reasons": [
    "Sleep duration turun 110 menit dari baseline",
    "Sleep efficiency turun lebih dari 10 poin",
    "Resting HR meningkat pada hari yang sama"
  ],
  "last_notification_at": "2026-09-06T08:01:00+07:00",
  "cooldown_until": "2026-09-07T08:01:00+07:00"
}
```

---

## 16. Pseudocode evaluasi

```python
features = build_daily_features(user_id, date)
baseline = get_active_baseline(user_id)
context = get_context_tags(user_id, date)

sleep_result = evaluate_sleep_rules(features.sleep, baseline.sleep, context)
activity_result = evaluate_activity_rules(features.activity, baseline.activity, context)
heart_result = evaluate_heart_rules(features.heart, baseline.heart, context)
bp_result = evaluate_bp_rules(features.blood_pressure, baseline.bp, context)

for result in [sleep_result, activity_result, heart_result, bp_result]:
    update_daily_condition(user_id, result.domain, result.daily_condition)
    transition_concern_state(
        user_id=user_id,
        domain=result.domain,
        daily_result=result,
        history=get_recent_history(user_id, result.domain, days=7)
    )

overall = calculate_overall_status(
    sleep=sleep_result,
    activity=activity_result,
    heart=heart_result,
    blood_pressure=bp_result,
    concern_states=get_concern_states(user_id)
)

if should_notify(overall, user_id):
    if overall.status == "URGENT":
        message = render_urgent_template(overall)
    elif overall.status in ["WARNING", "CAUTION"]:
        llm_context = build_safe_llm_context(overall)
        message = generate_and_validate_llm_insight(llm_context)
    else:
        message = render_template(overall)

    deliver_notification(user_id, message)
```

---

## 17. Safety guardrails

1. Jangan tampilkan “diagnosis” dari sleep, steps, RHR, HRV, atau Apple Watch.
2. Jangan jadikan Apple Watch sumber pembacaan tekanan darah mmHg.
3. Jangan memberi saran mengubah dosis obat.
4. Jangan menyebut penyebab pasti hanya dari korelasi data wearable.
5. Untuk event urgent, gunakan teks template yang disetujui dan jangan memanggil LLM.
6. Gunakan wording: “dapat berkontribusi”, “dapat berkaitan”, “perlu check-in”, “pertimbangkan konsultasi”.
7. Semua alert harus actionable dan memiliki cooldown untuk mencegah alert fatigue.
8. Catat audit trail: data apa, rule apa, state apa, dan notifikasi apa yang menghasilkan output.
9. Data kesehatan adalah sensitif: minimalkan data, enkripsi saat transit/penyimpanan, gunakan consent, dan sediakan penghapusan data.
10. Validasi rules dan pesan bersama tenaga kesehatan sebelum uji pengguna nyata.

---

## 18. Evaluasi MVP

### 18.1 Evaluasi teknis

| Area | Metrik |
|---|---|
| Data sync | Persentase hari dengan data valid; delay sinkronisasi |
| Feature engine | Kesalahan kalkulasi SE, deviation, baseline, dan frequency |
| Rule engine | Unit-test tiap rule dan tiap edge case |
| State machine | Akurasi transisi pada skenario sintetis |
| Notifications | Push rate per user per minggu; duplicate alert rate |
| LLM | Schema-valid rate, factuality, unsafe-content rate, fallback rate |

### 18.2 Evaluasi user/caregiver

| Pertanyaan | Indikator |
|---|---|
| Apakah caregiver memahami alasan caution? | Comprehension score / interview |
| Apakah rekomendasi dapat dilakukan? | Actionability rating |
| Apakah notifikasi terlalu sering? | Alert burden / perceived usefulness |
| Apakah insight meningkatkan check-in caregiver? | Self-report / interaction logs |
| Apakah pesan membuat panik? | Safety/usability feedback |

### 18.3 Dataset awal

Untuk awal, gunakan **data sintetis** dan skenario tervalidasi, bukan mengklaim prediksi klinis.

Skenario minimal:

1. Baseline baik dan stabil.
2. Baseline buruk tetapi stabil.
3. Satu malam tidur buruk lalu pulih.
4. Tidur pendek berulang.
5. Tidur buruk + activity turun.
6. Activity turun tajam, data wear time cukup.
7. HR tinggi saat workout lalu pulih.
8. RHR meningkat beberapa hari + HRV turun.
9. Fall event.
10. Irregular rhythm event.
11. Tensi meningkat bersama sleep concern.
12. Data hilang karena watch tidak dipakai.

---

## 19. Roadmap implementasi

### Phase 0 — Desain dan validasi

- Finalkan data dictionary.
- Finalkan rule catalog dan wording Bahasa Indonesia.
- Diskusikan clinical safety dengan dosen/tenaga kesehatan.
- Buat data sintetis dan test cases.

### Phase 1 — MVP tanpa LLM

- HealthKit permissions dan ingestion.
- Storage raw data dan daily features.
- Baseline 14 hari.
- Sleep/activity/heart rule engine.
- Dashboard per domain.
- State machine dan cooldown.
- Template insights Bahasa Indonesia.

### Phase 2 — Caregiver workflow

- Push notification.
- Acknowledge alert: “sudah dihubungi”, “sedang sakit”, “sedang bepergian”, “false alert”.
- Context tags.
- Weekly summary.
- Manual/BLE blood-pressure input.

### Phase 3 — LLM terbatas

- Gemini structured output.
- Output schema validator.
- Template fallback.
- Benchmark 20–50 skenario sintetis.
- Review human-in-the-loop atas output.

### Phase 4 — AI/anomaly detection opsional

- Tambahkan model anomaly detection personal setelah baseline cukup.
- Gunakan sebagai sinyal tambahan, bukan pengganti safety rules.
- Jangan menggunakan supervised learning sebelum memiliki label outcome yang valid dan cukup.

---

## 20. Keputusan yang perlu dikonfirmasi

1. Apakah target lansia adalah 60+, 65+, atau orang tua dewasa dengan hipertensi?
2. Apakah proyek hanya monitoring Apple Watch, atau wajib integrasi tensimeter?
3. Apakah dashboard caregiver ada di iOS yang sama, aplikasi terpisah, atau web?
4. Siapa yang dapat melihat data: anak tunggal, beberapa caregiver, atau tenaga kesehatan?
5. Apa kebijakan untuk Fall Detection dan irregular rhythm event?
6. Apakah target penelitian adalah usability, kualitas early caution, perubahan perilaku, atau prediksi outcome?
7. Apakah LLM diperlukan untuk MVP, atau cukup template agar evaluasi lebih terkontrol?

---

## 21. Ringkasan satu paragraf untuk proposal

Sistem ini memanfaatkan data sleep, aktivitas, mobilitas, dan indikator fisiologis dari Apple Health/Apple Watch untuk membangun baseline personal lansia selama 14 hari. Data kemudian diolah menjadi fitur harian dan dievaluasi melalui rule engine berbasis ambang umum, perubahan terhadap baseline, serta frekuensi kejadian. State machine mengelola apakah suatu concern baru muncul, menetap, memburuk, membaik, atau selesai sehingga notifikasi tidak berulang secara berlebihan. LLM digunakan secara terbatas hanya untuk menghasilkan ringkasan Bahasa Indonesia bagi caregiver berdasarkan fakta dan tindakan yang telah ditetapkan sistem; LLM tidak melakukan diagnosis, menentukan risiko klinis, atau memberi perubahan terapi.
