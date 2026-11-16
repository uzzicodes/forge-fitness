# FORGE
A local fitness app for your Windows computer and iPhone. Source: D:\forge_fitness

## Use it now
Run Start-Forge.cmd and open http://localhost:8787 on your computer.
On your iPhone, connect to the same Wi-Fi and open the iPhone setup address printed by the server in Safari.
The current setup address is http://192.168.1.132:8787/iphone (your IP may change).
Safari → Share → Add to Home Screen. Use Open as Web App if offered.
No APK is needed for an iPhone.

## Offline access at the gym
Plain HTTP on a LAN cannot install a service worker on iPhone. It needs the computer to be reachable when reloading.
For a locally hosted offline web app:
1. Run Setup-iPhone.cmd on the computer. Certificate files have already been generated for the current local IP.
2. Run or restart Start-Forge.cmd.
3. On your iPhone, open the /iphone setup page. Follow its certificate installation and trust instructions.
4. Open https://YOUR_COMPUTER_IP:8788/ after trusting your computer's FORGE certificate.
5. Add that secure app to your Home Screen, open it while connected, and wait for Offline ready.
6. Test reopening with Wi-Fi and cellular disabled before relying on it in the gym.

Screens, workout logs, manual meals, progress and targets can use the cached app. AI estimates need internet AND access to your computer server.
Browser storage can be evicted; export backups regularly. Data in HTTP, HTTPS, Safari and the Home Screen app may be separate.
If the computer IP changes, rerun Setup-iPhone.cmd (it retains the existing CA), restart the server, and use the new address. Export data before changing app origin.
Do not bypass certificate warnings. The setup changes no Windows trust settings. You manually decide whether to trust the local CA on your iPhone.
Private certificate keys stay in server/certs and are excluded from Git. Only the public CA certificate is served.
A native iOS build has not been created or tested. This Windows-only version uses an iPhone Home Screen web app.

## Nutrition by name or photo
1. Open http://localhost:8787/configure on the computer. Desktop pairing is automatic.
2. Enter your own OpenAI API key in that private local form and choose Verify & connect. Do not paste the key into chat.
3. Return to FORGE. The key is verified and saved locally; no restart is needed.
4. The desktop app pairs automatically. For your iPhone, use the private paired link on the computer setup page after certificate setup. Advanced pairing is still available in Settings.
   Leave the address blank in the web app to use its current origin.
5. Log meal → type a name (for example banana shake), choose a photo, or both.
   Optionally add portion/ingredient notes, then tap Estimate calories & protein.
6. Review serving size, assumed recipe and macros. Confirm to update the daily rings.

Name-only requests assume a typical serving when none is supplied. A banana shake can vary substantially with milk, banana count and sugar.
Estimates are not measurements. Weighed ingredients and nutrition labels are more accurate.
No photo files are saved by the server or meal journal. Photos and text go to OpenAI only when you request an estimate.
OPENAI_MODEL defaults to gpt-4.1-mini and can be changed in server/.env. OpenAI API usage may be billed separately.
No real AI request was tested because an API key was not supplied. API request shape, errors, image validation and name-only flows were tested with an injected model response.

## Training that follows you
Select 2–5 preferred weekdays in your profile. The default is Monday–Friday, with Saturday and Sunday for recovery.
The daily check-in asks whether you are training or resting.
The next workout is determined by your most recent completed session, not by a fixed weekday.
A missed/rest day holds the queue. If Monday is missed, Tuesday offers the next unfinished workout.
The 5-session rotation is push, pull, legs, upper body and lower body. Two/three-day schedules use full body, four days use upper/lower.
Each completed set saves actual reps/seconds and weight. Finish workout advances the queue only after all planned sets are checked.
Future week entries are forecasts assuming planned attendance, and never change the real queue.
Saved workouts retain their exercise list if equipment or schedule changes.
Illustrations are simplified movement previews with written setup and form cues.

## Local data
Profile, nutrition, attendance, workouts, water and weight check-ins are stored on each device.
Computer and phone histories do not sync automatically.
Settings → Export backup copies versioned JSON. Save the text in a file. Restore backup replaces that device's data after validation.
Weight check-ins do not automatically change profile targets. Update profile weight to recalculate estimates.

## Nutrition calculations
Mifflin–St Jeor resting energy × chosen activity factor, plus 200 kcal for the muscle-building goal; other goals use estimated maintenance.
Protein starts at 1.6 g/kg of profile weight. Targets can be overridden.
These are adult starting estimates, not medical prescriptions.
Sources:
- https://pubmed.ncbi.nlm.nih.gov/2305711/
- https://pmc.ncbi.nlm.nih.gov/articles/PMC5477153/
- https://acsm.org/resistance-training-guidelines-update-2026/
- https://developers.openai.com/api/docs/guides/images-vision
- https://developers.openai.com/api/docs/guides/structured-outputs
- https://support.apple.com/guide/iphone/open-as-web-app-iphea86e5236/ios
- https://support.apple.com/en-us/102390

## Develop and rebuild
Flutter 3.41.7 / Dart 3.11.5 and Node 24 were used.
Run tools/Build-Forge.ps1 to resolve dependencies, analyze, test, build web and prepare its offline cache.
The script invokes the installed Flutter snapshot directly because flutter.bat hung on this machine.
Run node --test server/server.test.mjs for backend tests.
For optional Android only: tools/Build-Forge.ps1 -Android. The original personal testing APK used a development signing certificate; it is not an iPhone app.
Run flutter test test/capture_preview.dart --update-goldens for example-data visual previews (uses Windows fonts when present).

## Verification limits
Core calculations, editing, persistence, layout, workout sets, attendance/queue rules, API adapters and the local server have automated checks.
Rendered phone and computer previews were visually inspected.
A physical iPhone camera, installation, certificate trust and offline reopening still need to be checked on your phone.
The browser automation runtime failed to start; no Safari end-to-end success is claimed.


