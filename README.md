# دفتر الديون — FADEL Debt & Credit Tracker

Flutter Android app for tracking client debts and payments across multiple employees' devices, syncing live via Firebase Firestore. UI is Arabic, RTL-first. Works fully offline and syncs when connectivity returns.

## Tech stack

- Flutter (Material 3, Arabic/RTL), Riverpod, go_router
- Firebase: Firestore (offline persistence enabled) + Anonymous Auth
- `flutter_secure_storage` for the local PIN (salted SHA-256 hash, never plaintext)
- Android only, `minSdk 23`, package `com.fadel.debtcredit`

## One-time Firebase setup (already done / to do once)

In the [Firebase Console](https://console.firebase.google.com/project/masareef-7cd62):

1. **Firestore**: Build → Firestore Database → Create database → Production mode → pick a region → Enable.
2. **Anonymous Auth**: Build → Authentication → Sign-in method → Anonymous → Enable → Save.
3. **Register the Android app** — from the project root:
   ```
   npm install -g firebase-tools        # if not installed
   dart pub global activate flutterfire_cli
   firebase login
   flutterfire configure --project=masareef-7cd62 --platforms=android
   ```
   This generates `lib/firebase_options.dart` and `android/app/google-services.json`.
   `google-services.json` is gitignored — every fresh clone must re-run `flutterfire configure` (or copy the file in manually to `android/app/`).
4. **Deploy the security rules**:
   ```
   firebase deploy --only firestore:rules
   ```
5. **Create the business** (see below).

## Creating a business (admin only — the app can't do this)

The app only ever **joins** an existing business. A mistyped ID fails with a clear error instead of silently creating a phantom business. To create one:

- **Option A — Console**: Firestore Database → Start collection → collection ID `businesses` → document ID e.g. `F@del` → add field `createdAt` (timestamp) → Save.
- **Option B — script**:
  1. Console → Project settings → Service accounts → Generate new private key → save as `tool/serviceAccountKey.json` (gitignored, never commit).
  2. ```
     cd tool
     npm install
     node create_business.js "F@del"
     ```

## Running the app

```
flutter pub get
flutter run          # with an Android device/emulator connected
```

Build a release APK: `flutter build apk`.

## Linking a new employee's device

1. Install the app on their phone.
2. On first launch the app asks for the **Business ID** — they type the ID shown in **Settings → معرّف النشاط التجاري** on any already-linked device (e.g. `F@del`). There's a copy button to share it.
3. They set their own 4-6 digit PIN. Done — the device now reads/writes the shared business data.

The PIN is per-device (not shared). The app locks on launch and after being backgrounded past the timeout set in Settings (default 2 minutes).

## Data model

```
businesses/{businessId}                     — created by admin only
  members/{uid}                             — one per linked device (anonymous auth uid)
  clients/{clientId}                        — name, phone?, notes?, balance (denormalized), timestamps
    transactions/{transactionId}            — type: debt|payment, amount, date, note?, createdBy, createdAt
```

Client balance = debts − payments, maintained atomically on every transaction write via `FieldValue.increment` in a `WriteBatch` (offline-safe; increments merge correctly across devices). Security rules (`firestore.rules`) restrict all client/transaction access to devices with a membership doc under that specific business.

## Currencies

Two currencies: USD (`$`) and Syrian Pound (`ل.س`). Each transaction carries a currency (selector on the form, USD default); every client keeps an **independent balance per currency** — amounts are never converted. To add another currency, extend `AppCurrency` in `lib/core/constants/currency_config.dart` (one enum value + symbol/format/balance-field).

## Printing statements

The print button on a client's screen builds a 58mm thermal-roll PDF (كشف حساب) and opens the Android share sheet — send it to a printer app (vendor app / RawBT / system Print) or share it to the client directly. Paper width is a constant in `lib/features/clients/services/receipt_printer.dart`.

## Note on build repositories

`android/build.gradle.kts` and `settings.gradle.kts` include the Aliyun mirror of Google's Maven repository as a fallback — dl.google.com is intermittently unreachable from some networks, and Gradle falls through to the mirror automatically.
