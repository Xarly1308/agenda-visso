# Agenda Visso — Project Summary

## Goal
Complete both apps (professional + patient) for single-professional optometry clinic with Firestore REST, appointment scheduling, push notifications via FCM, OTA updates, email via Resend API.

## Architecture
- **Firebase project**: `agendavisso`
- **Patient app**: `https://agendavisso.web.app` (Flutter web, Firebase Hosting target `paciente`)
- **Professional app**: `https://agendavisso-pro.web.app` (Flutter Android + web, Firebase Hosting target `pro`)
- **Cloud Functions**: Node.js 20 (1st gen) — `enviarConfirmacion`, `enviarRecordatorios`, `enviarReagendamiento`
- **Email**: Resend API (native `fetch`, no nodemailer)
- **Auth**: Anonymous Firebase Auth + Bearer token for Firestore REST v1 calls
- **OTA**: `ota_update` package + GitHub Releases (PackageInstaller API, `usePackageInstaller: true`)

## Current State
- Latest APK: **v1.2.7** — `https://github.com/Xarly1308/agenda-visso/releases/download/v1.2.7/app-release.apk`
- OTA version doc: `app_version/latest` in Firestore
- `kAppVersion = '1.2.7'` in `config_screen.dart`
- `pubspec.yaml version: 1.2.7+1`

## Key Implementation Details
- Single-professional: auto-selects first professional with horarios from Firestore
- Colombian locale: Spanish, AM/PM, numeric document, phone 10 digits, Colombian holidays
- Firestore REST v1 with Bearer token auth (API key alone insufficient for security rules)
- Polling (15s Timer) replaces WebChannel for citas in professional app
- Push via FCM topics (`profesional_notificaciones`) — single topic for single-professional
- `NotificacionService.init()` fire-and-forget in `main()` (avoid hang on platform channel calls)
- `addNotificacion` auto-generates UUID when `id` is empty
- NotificacionProvider auto-refreshes every 15s
- OTA progress dialog: modal with `PopScope(canPop: false)`, linear indicator, percentage, "No cierres la aplicación" warning
- OTA `usePackageInstaller: true` — confirmed working on POCO C85 (Android 15/MIUI)
- Email template: logo (GitHub raw URL), sede-specific contact info (address + phone per sede), "Cita Agendada" title, cancel info
- Resend configured: `resend.apikey` + `resend.from = "onboarding@resend.dev"` (test mode)
- SMTP/nodemailer removed from dependencies

## Known Issues
- **Push notifications not delivered on device** — Cloud Function sends push (logged "Push enviado al profesional"), but POCO C85 (MIUI) doesn't show notification. Likely MIUI battery optimization / notification settings. User hasn't confirmed after v1.2.7.
- **Resend test mode** — `onboarding@resend.dev` only sends to verified emails; need custom domain for production delivery.
- **FreeDomain** (`https://github.com/DigitalPlatDev/FreeDomain`) evaluated but may have deliverability issues; hold off for now.

## Sede Contact Info (for email template)
- **Acrópolis Visso**: Cra 45 #24-26, Barrio Quintaparedes, Bogotá D.C. / 315 342 5703
- **Visso Funza**: Cra 13 #16-85, C.C Micentro Funza, Funza, Cundinamarca / (601) 823-7298 - 315 342 5703

## Next Steps
1. Investigate push notification delivery on POCO C85 (MIUI settings: Autostart, battery optimization, notification permissions)
2. Add push for status changes (confirm/cancel) via `onUpdate` Cloud Function
3. Migrate from `functions.config()` to params package (deprecation deadline March 2027)
4. Upgrade `firebase-functions` package (Node 20 runtime deprecation warning)
5. Resolve cleanup policy for container images in us-central1 (`firebase functions:artifacts:setpolicy`)
6. Custom domain for Resend (production email)
