# Patient Health (iOS)

Native iOS app for patient demographics and daily vitals. Data is stored on the device, uploaded to a FHIR R4 server for consented patients, and shown on a 7-day dashboard with CSV and PDF export. Android and Flutter versions live in separate repositories.

## Stack
SwiftUI, SwiftData, MVVM with `@Observable`, Swift Charts, URLSession async/await, BGTaskScheduler, Keychain. iOS 17.0 or later.

## Layout
- `PatientHealth/Models` – Patient, VitalRecord, AuditLogEntry and enums
- `PatientHealth/Services` – validation, unit conversion, FHIR mapper and client, sync, export, Keychain, background sync
- `PatientHealth/ViewModels`, `PatientHealth/Views` – screens and their state
- `PatientHealthTests` – unit tests
- `Config/Info.plist` – background task identifiers

## Build and test
Open `PatientHealth.xcodeproj` in Xcode, or from the command line:
```bash
xcodebuild test -project PatientHealth.xcodeproj -scheme PatientHealth \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGN_IDENTITY=-
```
Use `CODE_SIGN_IDENTITY=-` (not `CODE_SIGNING_ALLOWED=NO`): the Keychain tests need an ad-hoc signed host app. Substitute any installed simulator name.

Debug builds accept the launch argument `-seedDemoData` to create a synthetic sample patient with a week of vitals. It is compiled out of Release builds.

## FHIR server
The environment is chosen in Settings (Development, Staging, Production). Development currently points at the public `hapi.fhir.org` test server, which is shared and not private: use synthetic data only.

## Security and privacy
- Local store uses complete file protection and is excluded from backups.
- Uploads happen only for patients who gave consent.
- The audit log records actions and IDs only, never clinical values.

## Known gaps
No separate Dev/QA/Prod build configurations, no localization, no UI tests, no lint run. Background sync is built but only compile-checked; iOS decides when it runs.
