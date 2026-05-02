/// OneSignal App ID (dashboard: Settings → Keys & IDs).
///
/// Build with: `flutter run --dart-define=ONESIGNAL_APP_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
/// or set [defaultValue] below for local dev only (do not commit secrets).
const String kOneSignalAppId = String.fromEnvironment(
  'ONESIGNAL_APP_ID',
  defaultValue: '57dff4f4-7e5e-4573-9556-e5a9427df902',
);

//flutter run --dart-define=ONESIGNAL_APP_ID=57dff4f4-7e5e-4573-9556-e5a9427df902