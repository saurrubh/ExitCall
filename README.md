# ExitCall - Escape from Awkwardness

**[Download the Android APK](https://github.com/saurrubh/ExitCall/releases/latest)**

Exit Call is a small Flutter app for scheduling a simulated incoming call on Android. It's for those moments when you could use a reason to step away. Pick a caller, set a delay, and the call screen appears when it's time.

## Using the app

1. Enter a caller name and, if you want, a number to display.
2. Pick a call style. The options are inspired by Google Phone, Samsung Phone, and WhatsApp, with a simple Classic style too.
3. Tap **Preview incoming call** to try the screen right away, or choose a delay or a specific time and tap **Schedule call**.

Turn on **Repeat every minute** to ring again one minute after the first call. Tap **Stop** on the scheduled call card to end the loop.

Choose **System Phone** to use your device's default Phone app. Open **Calling accounts** and enable **Exit Call** once, then preview or schedule as usual. The Phone app controls the screen and may list simulated calls in Recents.

Exit Call keeps one schedule at a time. Calls are simulated locally.

Android may ask you to allow notifications and **Alarms & reminders** when you schedule your first call. Turn on **Show on lock screen** if you want the incoming screen to open over the lock screen. Depending on your Android settings, the call may appear as a notification you can tap to open.

## Volume Up shortcut

Press **Volume Up** twice quickly on the main screen to schedule one call for 10 seconds later. It uses the caller and call appearance you picked.

To use the shortcut from another app, tap **Enable background shortcut** in Exit Call. Turn on **Exit Call volume shortcut** under Android's **Accessibility** settings, then leave the app or dismiss it from Recents. Keep the display awake if your device suppresses volume events with the screen off.

The shortcut checks the volume-key gesture and the buttons keep adjusting the volume. Android's **Alarms & reminders** access is required for scheduling. The built-in appearances also need notifications, and **System Phone** needs its calling account. If a call is already scheduled, the background shortcut leaves it in place.

Turn the service off in **Background shortcut settings** whenever you want to disable the shortcut outside Exit Call. If Android restricts the Accessibility switch for a sideloaded copy you trust, see [Android's restricted settings help](https://support.google.com/android/answer/12623953).

The volume shortcut is available in builds from the current source.

## Designing a call screen

Tap **Customize call screen** near the top of the home screen. Drag items around the preview or use the position sliders to place them precisely. You can change text and button sizes, choose solid or gradient colors, and set a gesture for each call control. Switch between incoming and answered previews as you work. Saving selects your **Custom** appearance, ready for a preview or a scheduled call.

In **Controls**, select **Answer**, **Decline**, or **End call** to set that button’s width, height, label size, and icon size separately.

## Running it from source

You'll need Flutter, Android SDK Platform 36, and JDK 17. Start an Android emulator or connect a phone with debugging enabled. Exit Call supports Android 8.0 and later. With Flutter on your PATH, run these commands from the project folder.

```sh
flutter pub get
flutter run
```

On Windows, you can also run `.\run.ps1` from PowerShell. It uses the workspace Flutter SDK if one is present.

To build an APK you can install, run `flutter build apk --release` or `.\build.ps1` on Windows. The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

Local builds use Android debug signing. GitHub release APKs use the Exit Call release key. The [F-Droid build recipe](.fdroid.yml) uses the same source and builds an unsigned APK for repository signing. Listing text and the release changelog live in [Fastlane metadata](fastlane/metadata/android/en-US).

## License

Exit Call is licensed under the [MIT License](LICENSE).

The Gradle wrapper files retain their [Apache 2.0 license](LICENSES/Apache-2.0.txt).
