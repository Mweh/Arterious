# CloudKit Dashboard — Schema Setup Guide

Container: `iCloud.com.helloworld.arterious`
Database: **Public Database**

Go to: [CloudKit Console](https://icloud.developer.apple.com/dashboard/) → your container → **Schema** → **Record Types**

---

## Record Type 1: `SharingInvite`

### Fields

| Field Name | Type | Notes |
|---|---|---|
| `inviteCode` | String | Required. 8-char alphanumeric invite code. |
| `status` | String | `"pending"` or `"accepted"` |
| `childDeviceID` | String | UIDevice identifier of the child device |

### Indexes (required for querying)

| Field | Index Type |
|---|---|
| `inviteCode` | **Queryable** |
| `status` | Queryable |
| `recordName` | Queryable (default) |
| `modificationDate` | Sortable (default) |

---

## Record Type 2: `ParentHealthSnapshot`

### Fields

| Field Name | Type | Notes |
|---|---|---|
| `inviteCode` | String | FK reference to the SharingInvite code |
| `snapshotJSON` | String | Full JSON of `DailyHealthSummary` |
| `parentName` | String | Display name of the parent |
| `updatedAt` | Date/Time | Timestamp of last push |

### Indexes (required for querying + subscription)

| Field | Index Type |
|---|---|
| `inviteCode` | **Queryable** |
| `updatedAt` | **Sortable** |
| `recordName` | Queryable (default) |
| `modificationDate` | Sortable (default) |

---

## Record Type 3: `HealthRecord`

Struktur record kesehatan harian individual yang digunakan untuk query data harian & riwayat anak.

### Fields

| Field Name | Type | Description |
|---|---|---|
| `inviteCode` | String | Kode invite pairing |
| `recordDate` | Date/Time | Tanggal record (misal 9 Sep 2026) |
| `parentName` | String | Nama orang tua |
| `restingHeartRate` | Double | RHR dalam BPM (misal 72) |
| `heartRateStatus` | String | Status detak jantung (misal "Dalam rentang normal") |
| `recentHeartRatePoints` | String | Nilai koma untuk mini sparkline (misal "70,71,72,70,72") |
| `sleepHours` | Double | Jam tidur (misal 7.66) |
| `sleepFormatted` | String | Format tampilan (misal "7j 40m") |
| `sleepStatus` | String | Status tidur (misal "Kualitas tidur baik") |
| `recentSleepPoints` | String | Nilai koma untuk mini sparkline (misal "6.8,7.2,7.5,7.6") |
| `stepCount` | Int64 | Jumlah langkah (misal 4280) |
| `stepFormatted` | String | Format tampilan (misal "4.280") |
| `activityStatus` | String | Status aktivitas (misal "Lebih baik dari biasanya") |
| `recentStepPoints` | String | Nilai koma untuk mini sparkline (misal "3500,4000,4200,4280") |
| `summaryTitle` | String | Judul ringkasan hari ini (misal "Kondisi cukup stabil") |
| `summaryBody` | String | Teks ringkasan kondisi orang tua |
| `updatedAt` | Date/Time | Waktu update terakhir |

### Indexes (required in CloudKit Dashboard)

| Field | Index Type |
|---|---|
| `inviteCode` | **Queryable** |
| `recordDate` | **Sortable** |
| `updatedAt` | **Sortable** |
| `recordName` | Queryable (default) |
| `modificationDate` | Sortable (default) |

---

## Security Roles (Public DB Permissions)

In CloudKit Dashboard → **Security Roles**:

| Record Type | Role | Read | Write | Create |
|---|---|---|---|---|
| `SharingInvite` | `World` (any iCloud user) | ✅ | ✅ | ✅ |
| `ParentHealthSnapshot` | `World` | ✅ | ✅ | ✅ |

> **Note**: In production you would tighten this. For the MVP/hackathon, `World` write access is acceptable since the invite code acts as a shared secret.

---

## Push Notification (for CKQuerySubscription)

No extra CloudKit dashboard configuration is required for subscriptions.  
However, in Xcode **Signing & Capabilities**, make sure:
- ✅ **Push Notifications** capability is added
- ✅ **CloudKit** capability shows the container

And in `AppDelegate` (or `ArteriousApp`), register for remote notifications:

```swift
UIApplication.shared.registerForRemoteNotifications()
```

---

## Steps to Add URL Scheme in Xcode (No Info.plist)

Since this project uses modern Xcode without a separate Info.plist:

1. In Xcode, click on **Arterious** in the project navigator (blue icon)
2. Select **Arterious** target
3. Go to **Info** tab
4. Scroll down to **URL Types** section
5. Click **+**
6. Set:
   - **Identifier**: `com.helloworld.arterious`
   - **URL Schemes**: `arterious`
   - **Role**: Editor

This enables `arterious://invite?code=XXXX` links to open the app.
