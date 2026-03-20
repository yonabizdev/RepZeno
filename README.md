# RepZeno

RepZeno is a local-first workout tracker built with Flutter. It stores workouts,
sets, and custom exercises on-device so users can log progress without creating
an account.

## Release Notes

### Privacy and data handling

- Workout history, sets, and custom exercises are stored locally in the app database.
- The app does not include ads, analytics SDKs, account sync, or remote APIs.
- Android cloud backup and device-transfer backup are disabled for app data.
- On iOS, the workout database is excluded from iCloud backup.
- A user-facing privacy screen is available in the app drawer under `Privacy & Data`.

### Android release signing

This project is configured for a real upload keystore instead of the debug key.
Before publishing:

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Replace the values with your real keystore path, alias, and passwords.
3. Build a Play Store upload using:

```bash
flutter build appbundle --release
```

### Store console checklist

- Add a public privacy-policy URL in Google Play Console.
- Add a public privacy-policy URL in App Store Connect.
- Review Play Data safety answers and Apple App Privacy details so they match the current app behavior.
- Set your final bundle identifiers, signing team, version number, screenshots, and store listing copy before release.
