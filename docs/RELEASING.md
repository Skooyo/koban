# Releasing Koban

This runbook tells you how to build, publish and roll out a new Koban version to friends. It is for the owner, who releases Koban alone, and for a coding agent that helps.

Koban is the Flutter app in `koban/` from version 0.2.0 (`versionCode` 3). The Kotlin app in `app/` made 0.1.0 and 0.1.1. Do not release the Kotlin app again: friends with 0.2.0 or later cannot install a lower `versionCode`.

The repository is public. Do not write a password, a key or a server URL in this file, in a commit or in a chat. Refer to the files in `~/.koban/` by name only.

## 1. Rules that never change

Break one of these rules and friends lose data or stop getting updates.

1. Never change the app ID `io.github.skooyo.koban`. Android treats a new ID as a different app.
2. Never lose or replace the release key `~/.koban/koban-release.jks`. Android installs an update only when the new APK has the same key. With another key, friends must uninstall Koban and lose their data.
3. Give every APK a higher `versionCode` than the APK before it. Android refuses a lower or equal `versionCode`.
4. Never publish a debug build. A debug build has the app ID `io.github.skooyo.koban.debug` and the debug key.
5. Never delete a release asset that friends can download. A friend can be in the middle of a download.

## 2. One-time setup

Do these steps once, on the computer that makes releases.

1. Keep the release key at `~/.koban/koban-release.jks` (alias `koban`, PKCS12).
2. Keep the passwords at `~/.koban/release-signing.properties`. It has the keys `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. `koban/android/app/build.gradle.kts` reads this file. If the file is missing or a key has no value, a release build stops with the error "Release signing file ... is missing or has no value for ...". It never signs a release with the debug key. Debug builds and unit tests do not need the file.
3. Back up the two files in two places. Keep one of the two places offline. For example, use a USB drive and a password manager. Without these files, you cannot make an update for the friends who have Koban.
4. Keep the two Android OAuth clients in Google Cloud. One client is for `io.github.skooyo.koban` with the release key SHA-1. One client is for `io.github.skooyo.koban.debug` with the debug key SHA-1. `~/.koban/oauth-sha1.txt` has the two SHA-1 values. Google sign-in fails when the SHA-1 of the APK is not in a client.
5. Install the GitHub CLI and sign in. Run the command below. It must show the account that owns `Skooyo/koban`.

   ```bash
   gh auth status
   ```

## 3. Release a new version

Use Git Bash, from the `koban/` folder (not the repository folder). Set `JAVA_HOME` to your JDK 17 for each command that needs it. In the commands, `<versionCode>` and `<versionName>` are the new values. Example: `versionCode` 3, `versionName` 0.2.0.

1. Pick the new version.
   - `versionCode`: the old value + 1.
   - `versionName`: MAJOR.MINOR.PATCH. Add 1 to PATCH for fixes only. Add 1 to MINOR for new features, and set PATCH to 0.
2. Open `koban/pubspec.yaml`. Change the line `version: <versionName>+<versionCode>`. Example: `version: 0.2.0+3`.
3. Run the checks. `flutter analyze` must show `No issues found!`. Every test must pass. Run the Kotlin tests as `:app:testDebugUnitTest`: the plain `testDebugUnitTest` also runs the tests of a plugin, and they fail.

   ```bash
   flutter analyze
   flutter test
   (cd android && JAVA_HOME="<your JDK 17>" ./gradlew.bat --console=plain :app:testDebugUnitTest)
   ```

4. Build the release APK. Do not add `--split-per-abi`: it adds 1000 x ABI to the `versionCode`, and then the updater does not find `koban-<versionCode>.apk`. The APK is `build/app/outputs/flutter-apk/app-release.apk`.

   ```bash
   JAVA_HOME="<your JDK 17>" flutter build apk --release
   ```

   The release build does not use R8 (no code shrink and no resource shrink), the same as 0.1.1. Do not turn R8 on without a test of the release APK on a phone: R8 can remove code that a plugin finds by name, and ML Kit then needs `-dontwarn` rules for its Chinese, Devanagari, Japanese and Korean option classes.
5. Check the signature of the APK.

   ```bash
   JAVA_HOME="<your JDK 17>" D:/Android/build-tools/36.0.0/apksigner.bat verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```

6. Compare the line `Signer #1 certificate SHA-1 digest` with the `io.github.skooyo.koban` line in `~/.koban/oauth-sha1.txt`. `apksigner` shows lowercase hex without colons. The file shows uppercase hex with colons. The 40 hex digits must be the same. If they are not the same, stop: the APK has the wrong key. Do not show the file in a chat: compare in a script that prints only "match" or "mismatch".
7. Check the version and that the APK is not debuggable. The first command must show `versionCode='<versionCode>'` and `versionName='<versionName>'`. The second command must print `0`. If it prints `1`, stop: the build is debuggable. Never publish it.

   ```bash
   D:/Android/build-tools/36.0.0/aapt2.exe dump badging build/app/outputs/flutter-apk/app-release.apk | head -1
   D:/Android/build-tools/36.0.0/aapt2.exe dump badging build/app/outputs/flutter-apk/app-release.apk | grep -c application-debuggable
   ```

8. Copy the APK to the name that the updater looks for. The updater reads the asset named `koban-<versionCode>.apk` and ignores other names. It also checks that the APK inside has this `versionCode`.

   ```bash
   cp build/app/outputs/flutter-apk/app-release.apk koban-<versionCode>.apk
   ```

9. Commit the version change. Tag the commit and push the tag.

   ```bash
   git add pubspec.yaml
   git commit -m "Release Koban <versionName>"
   git tag v<versionName>
   git push origin v<versionName>
   ```

   Do this step before step 10. If the tag is not on GitHub, `gh release create` makes a new tag on the tip of `main`, which can be the wrong code.
10. Create the GitHub release as a draft, with the APK. Friends cannot get a draft. Write the notes in Simplified Technical English. The "Update available" dialog shows the first 500 characters of the notes. The dialog shows the tag without the `v` as the version name.

   ```bash
   gh release create v<versionName> koban-<versionCode>.apk --verify-tag --draft --title "Koban <versionName>" --notes "<what changed, in STE>"
   ```

11. Install the APK on your own phone by USB. The latest-release API that Koban reads skips drafts, so "Check for updates" cannot see a draft.

   ```bash
   adb install -r koban-<versionCode>.apk
   ```

12. Use the new version on your phone for 1 day. Open Settings and make sure "App version" shows the new `versionName`. If you find a problem, do not publish. Fix it and start again at step 1.
13. Publish the draft. Friends get the update at their next daily check. See section 4.

    ```bash
    gh release edit v<versionName> --draft=false
    ```

14. Delete the local copy `koban-<versionCode>.apk`. Do not commit it.

## 4. Roll out

After you publish, the release is live. These things then occur:

1. Each friend's Koban checks GitHub once a day and shows "Update available". The check runs only when "Online features" is on.
2. The update is optional. A friend can tap "Later".
3. On the first update, Android asks the friend to allow "Install unknown apps" for Koban. Koban opens that settings page. The friend turns on the switch and goes back to Koban. If Koban shows the "Allow Koban to install apps, then tap Update again." message, the friend taps OK, then Update. If Android closed Koban, the friend opens Koban again and "Update available" shows.
4. Android closes Koban after the update and does not open it again. The friend opens Koban again.
5. To stop a bad release, mark it as a prerelease. Koban then stops offering it. See section 5.

## 5. Something is broken after a release

Android cannot go back to a lower `versionCode`. Fix forward with a new, higher version.

1. If the broken build destroys data, mark the release as a prerelease at once. Then Koban stops offering it to more friends.

   ```bash
   gh release edit v<versionName> --prerelease
   ```

2. Revert the bad change in git.

   ```bash
   git revert <commit>
   ```

3. Release the fix as a new version: `versionCode` + 1 and PATCH + 1. Follow section 3.
4. Do not delete the bad release or its APK. See rule 5 in section 1.

## 6. Backend changes

Old app versions stay in use for days, because updates are optional. The Supabase SQL, the RPCs and the Edge Functions must work for the oldest app in use.

1. Add new fields, tables and RPCs. Give new RPC parameters a default value.
2. Do not rename or remove a field, a parameter or an RPC until every friend has the update.
3. Do not change the meaning of a field that old apps read.

## 7. Add a friend

Each friend needs one invite code and a first install by USB. Updates after the first install come through the app.

Add friends only after one update (for example 0.1.0 to 0.1.1) installed on your own phone through Check for updates. If the updater in the first friend build is broken, every friend needs a USB reinstall.

1. Make one invite code for the friend. Open the SQL editor of the Supabase project in the Supabase dashboard. Run the query below and copy the code that it returns.

   ```sql
   select public.new_invite('<friend name>');
   ```

2. Download the APK of the latest release.

   ```bash
   gh release download v<versionName> --pattern "koban-<versionCode>.apk"
   ```

3. Install Koban on the friend's phone by USB. Do not send the APK in a browser or a chat app: Play Protect can block an APK that asks for notification access when it comes from there (ticket #27).
   1. On the friend's phone, turn on Developer options and USB debugging.
   2. On a Xiaomi phone, also turn on "Install via USB".
   3. Connect the phone and run the command below.

      ```bash
      adb install koban-<versionCode>.apk
      ```

4. The friend opens Koban and signs in with Google.
5. The friend enters the invite code, then joins your group with the group code.
6. Approve the friend on the group screen.

The first update after this install asks the friend to allow "Install unknown apps" for Koban. See section 4.

## 8. Known limits

- The APK is about 101 MB (0.2.0: 101,184,525 bytes; `flutter build` shows 96.5 MB, in units of 1024 x 1024 bytes), because of ML Kit, no R8 and the Flutter engine for 3 ABIs. 0.1.1 was about 65 MB. Each update downloads the full APK.
- Android closes Koban after a self-update and does not open it again. The friend opens Koban again.
- Koban calls the GitHub API without a token. GitHub allows 60 requests per hour per IP address. On a shared Wi-Fi with many Koban phones, GitHub can answer 403 for one hour. Koban shows no error and tries again the next day. A manual check shows "Could not check for updates. Try again later."
- Google developer verification applies in all countries in 2027 (ticket #26). Register before then. If you do not register, friends need `adb` or the "advanced flow" for new installs.
