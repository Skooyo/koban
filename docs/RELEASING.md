# Releasing Koban

This runbook tells you how to build, publish and roll out a new Koban version to friends. It is for the owner, who releases Koban alone, and for a coding agent that helps.

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
2. Keep the passwords at `~/.koban/release-signing.properties`. It has the keys `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. `app/build.gradle.kts` reads this file. If the file is missing, `assembleRelease` makes `app-release-unsigned.apk`, which you cannot install.
3. Back up the two files in two places. Keep one of the two places offline. For example, use a USB drive and a password manager. Without these files, you cannot make an update for the friends who have Koban.
4. Keep the two Android OAuth clients in Google Cloud. One client is for `io.github.skooyo.koban` with the release key SHA-1. One client is for `io.github.skooyo.koban.debug` with the debug key SHA-1. `~/.koban/oauth-sha1.txt` has the two SHA-1 values. Google sign-in fails when the SHA-1 of the APK is not in a client.
5. Install the GitHub CLI and sign in. Run the command below. It must show the account that owns `Skooyo/koban`.

   ```bash
   gh auth status
   ```

## 3. Release a new version

Use Git Bash, from the repository folder. Set `JAVA_HOME` to your JDK 17 for each command that needs it. In the commands, `<versionCode>` and `<versionName>` are the new values. Example: `versionCode` 2, `versionName` 0.1.1.

1. Pick the new version.
   - `versionCode`: the old value + 1.
   - `versionName`: MAJOR.MINOR.PATCH. Add 1 to PATCH for fixes only. Add 1 to MINOR for new features, and set PATCH to 0.
2. Open `app/build.gradle.kts`. Change `versionCode` and `versionName` in `defaultConfig`.
3. Run the unit tests and build the release APK.

   ```bash
   JAVA_HOME="<your JDK 17>" ./gradlew.bat --console=plain testDebugUnitTest assembleRelease
   ```

4. Check the signature of the APK.

   ```bash
   JAVA_HOME="<your JDK 17>" D:/Android/build-tools/34.0.0/apksigner.bat verify --print-certs app/build/outputs/apk/release/app-release.apk
   ```

5. Compare the line `Signer #1 certificate SHA-1 digest` with the `io.github.skooyo.koban` line in `~/.koban/oauth-sha1.txt`. `apksigner` shows lowercase hex without colons. The file shows uppercase hex with colons. The 40 hex digits must be the same. If they are not the same, stop: the APK has the wrong key.
6. Copy the APK to the name that the updater looks for. The updater reads the asset named `koban-<versionCode>.apk` and ignores other names. It also checks that the APK inside has this `versionCode`.

   ```bash
   cp app/build/outputs/apk/release/app-release.apk koban-<versionCode>.apk
   ```

7. Commit the version change. Tag the commit and push the tag.

   ```bash
   git add app/build.gradle.kts
   git commit -m "Release Koban <versionName>"
   git tag v<versionName>
   git push origin v<versionName>
   ```

   Do this step before step 8. If the tag is not on GitHub, `gh release create` makes a new tag on the tip of `main`, which can be the wrong code.
8. Create the GitHub release with the APK. Write the notes in Simplified Technical English. The "Update available" dialog shows the first 500 characters of the notes. The dialog shows the tag without the `v` as the version name.

   ```bash
   gh release create v<versionName> koban-<versionCode>.apk --verify-tag --title "Koban <versionName>" --notes "<what changed, in STE>"
   ```

   To test the release before friends get it, add `--draft`. See section 4.
9. Install the update on your own phone first. Open Koban, go to Settings, tap "Check for updates", then tap "Update". Settings shows "App version". Make sure it shows the new `versionName`.
10. Delete the local copy `koban-<versionCode>.apk`. Do not commit it.

## 4. Roll out

A published release is live at once. Each friend's Koban checks GitHub once a day and shows "Update available". The check runs only when "Online features" is on.

1. Use the new version on your own phone for 1 day before friends get it. To do this, create the release as a draft. The latest-release API that Koban reads skips drafts and prereleases.

   ```bash
   gh release create v<versionName> koban-<versionCode>.apk --verify-tag --draft --title "Koban <versionName>" --notes "<what changed, in STE>"
   ```

2. Install the APK on your phone by USB.

   ```bash
   adb install -r koban-<versionCode>.apk
   ```

3. After 1 day without problems, publish the draft.

   ```bash
   gh release edit v<versionName> --draft=false
   ```

4. Tell friends what to expect:
   - The update is optional. A friend can tap "Later".
   - On the first update, Android asks the friend to allow "Install unknown apps" for Koban. Koban opens that settings page. The friend turns on the switch, goes back and taps "Update" again.
   - Android closes Koban after the update and does not open it again. The friend opens Koban again.

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

1. Get the service key for the Supabase project. `<ref>` is the project ref in `~/.koban/supabase-project.txt`.

   ```bash
   npx supabase projects api-keys --project-ref <ref> --reveal -o json
   ```

   Use the key once, then delete it from the terminal and the clipboard. Never paste the key in a chat, a file or git.
2. Make one invite code for the friend. Send a POST request to `/rest/v1/rpc/new_invite` on the project API. Give the JSON body `{"p_friend_name": "<name>"}`. Put the service key in the `apikey` header and in the `Authorization: Bearer` header. The answer is the invite code.
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

- The APK is about 65 MB, because of ML Kit. Each update downloads the full APK.
- Android closes Koban after a self-update and does not open it again. The friend opens Koban again.
- Koban calls the GitHub API without a token. GitHub allows 60 requests per hour per IP address. On a shared Wi-Fi with many Koban phones, GitHub can answer 403 for one hour. Koban shows no error and tries again the next day. A manual check shows "Could not check for updates. Try again later."
- Google developer verification applies in all countries in 2027 (ticket #26). Register before then. If you do not register, friends need `adb` or the "advanced flow" for new installs.
