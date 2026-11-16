# FORGE Fitness & Fuel — Claude handoff

## What this is

FORGE is a mobile-first Flutter web/PWA fitness and nutrition tracker for Pakistan-based users. It is currently live at:

https://forge-fitness-fuel.mu03174401887.chatgpt.site/fitness/

It is installable to an iPhone Home Screen, but it is a web app—not a native iOS APK/app. It can be used without signing in (device-only mode) or with a signed-in online account (cloud sync).

## Source folders

* `D:\forge_fitness` — the primary Flutter app source to edit.
* `D:\forge_online` — hosted-site wrapper, Cloudflare Worker/API, D1 database migrations, deployed Flutter snapshot, test suite, deployment scripts, and QA evidence.
* `D:\forge_online\flutter-src` — the exact Flutter source snapshot used for the current v13 online deployment.
* `D:\forge_online\outputs\forge-personal-records-v13.tar.gz` — packaged release artifact of the current online version.

Do **not** paste API keys into source code, Git, public settings, or chat. The owner previously pasted a Gemini key into chat; treat it as exposed and ask them to revoke/regenerate it. Meal photos are analyzed transiently and must not be retained; save nutrition records only.

## Product requirements already implemented

### Nutrition

* Natural text logging: examples include “I ate 3 boiled eggs”, “banana shake”, “3 slices of Bunny's bread with dal”. A confirmation step occurs before adding food.
* Optional food-photo analysis only with a user-owned, privately configured AI key. The normal app must still work with text/manual logging without AI.
* Protein, calories, carbs, fat and daily targets; water tracking.
* Pakistan-oriented food reference (98 recipes plus USDA references), Open Food Facts product/barcode lookup, generic packaged-food fallback and user label/recipe support.
* Food guide with pictures and approximate Pakistan prices.
* The app must clearly label estimates. It must never claim a guessed serving or generic food is exact branded nutrition.

### Training

* Full-gym, aesthetic physique-oriented programme: a progressive, repeatable rotation rather than changing every exercise randomly every Monday.
* Workout selection follows the last completed training session, not just the calendar. If a scheduled day is missed, the next session continues the rotation.
* Exercises include gym machines/barbells/cables as well as dumbbells; every exercise has an alternate/swap path for a busy or unavailable machine.
* Session defaults are 2 working sets for beginner and 3 for more experienced users; reps are normally 8–12. “2 reps” is not the same as two sets.
* Personal Records (v13): PR and previous set on workout cards, PR history sheet, all-PRs progress screen. PR means heaviest recorded completed set, not a calculated 1RM. It updates immediately when sets are saved/reopened/swapped.

### Personalisation / progress

* Onboarding captures age, sex, height, weight, goals, activity and training experience.
* BMI/body-status and goal-aware calorie/protein guidance. Keep this as general wellness guidance—not diagnosis.
* Workout, protein/calorie, water, habit and streak tracking.
* Valorant-style rank/XP system. Weekly review applies fair deductions after Sunday only when targets were missed; no punishment for one occasional missed day. Recovery-week pause exists.
* Separate guest mode with local-only persistence and signed-in account mode with cloud sync. Never let guest activity write into an account or make unauthenticated state/sync calls.

## Architecture

* Flutter/Dart frontend in `D:\forge_fitness\lib`.
* The online project is a Next/Vinext-style site plus Cloudflare Worker API in `D:\forge_online`.
* Hosted runtime endpoints are in `D:\forge_online\lib\service.mjs`.
* D1 migrations are under `D:\forge_online\db` / `drizzle`.
* Guest endpoints are deliberately restricted to `/api/guest/...`; they must reject image and Gemini usage and must not access account records.
* The production app uses a service worker. Safari has previously had “Response served by service worker has redirections”; do not reintroduce navigation redirects inside service-worker responses.

## Important source files

* `D:\forge_fitness\lib\main.dart` — app state/mode orchestration.
* `D:\forge_fitness\lib\workout_screen.dart` — training session UI, swaps, set logging.
* `D:\forge_fitness\lib\exercise_records.dart` — normalised completed-set records and PR rules.
* `D:\forge_fitness\lib\personal_records.dart` — personal-record UI.
* `D:\forge_fitness\lib\guest_food_client.dart` — guest-safe food client.
* `D:\forge_online\lib\service.mjs` — online API and guest boundaries.
* `D:\forge_online\tests\browser-personal-records.mjs` — end-to-end PR flow test.
* `D:\forge_online\outputs\verify-pr-live.mjs` — deployed release verifier.

## Current release status

* Current release: v13 Personal Records.
* Deployment identifier: `appgdep_6ae64e7a81fc81919a40b0b921ae3788`.
* Source commit for current deployed release: `25e7bb12a0aef5082d25824a6350ccce2ca590d5`.
* The old `jazzylark16` hostname redirects to the current `mu03174401887` hostname. Guest local data is origin-specific, so users moving Home Screen icons should export a backup from the old icon and restore it at the current host.

## Validation that passed for v13

* Flutter analyzer: clean.
* Flutter unit/widget tests: passed.
* Node API tests: 60 passed.
* TypeScript check: clean.
* Flutter release web build: passed.
* Browser test: PR appears, opens history, updates immediately after a saved set, disappears after reopening, returns after re-saving, survives cloud reload, and keeps different equipment variants separate.
* Production deployment verifier: passed; compiled files matched the deployed production files.

Do not say the app is “error-free.” Make a change, run relevant tests, manually test the real mobile flow, then state exactly what passed.

## Local commands

The normal `flutter.bat` has previously hung in this Windows environment. Use the Flutter tool snapshot directly:

```powershell
& 'C:/flutter/bin/cache/dart-sdk/bin/dart.exe' 'C:/flutter/bin/cache/flutter_tools.snapshot' analyze --no-pub
& 'C:/flutter/bin/cache/dart-sdk/bin/dart.exe' 'C:/flutter/bin/cache/flutter_tools.snapshot' test --no-pub
& 'C:/flutter/bin/cache/dart-sdk/bin/dart.exe' 'C:/flutter/bin/cache/flutter_tools.snapshot' build web --release --base-href /fitness/ --dart-define=FORGE_HOSTED=true --no-web-resources-cdn --pwa-strategy=none --no-pub
```

For the online app:

```powershell
Set-Location D:\forge_online
node --test tests/*.test.mjs
node node_modules/typescript/bin/tsc --noEmit
npm run dev -- --host 127.0.0.1 --port 5173
```

After Flutter build, run `node scripts/prepare-flutter.mjs` from `D:\forge_online` to place production assets correctly.

## Guardrails for future changes

1. Preserve both guest and cloud-account paths.
2. Don’t make medical claims or prescribe extreme deficits/bulks. Use safe, general guidance and clear estimate labels.
3. Keep raw food photos transient; don’t add photo storage without fresh user approval.
4. Treat bodyweight, assisted and weighted exercises correctly in PR logic. For assisted movements, less assistance is better.
5. Preserve transparent rank/XP rules. Do not deduct XP retroactively before a user’s first full tracking week.
6. Keep exercise alternatives practical and clearly distinguish the exact machine/setup when comparing PRs.
7. Test PWA/service-worker behavior on Safari/iPhone after routing or cache changes.
8. Before sharing an updated link, check the actual current production hostname; hosting deployments may change it.

## Suggested next work (only if useful)

* Add a simple PR trend chart per exercise.
* Expand verified Pakistani branded package data only from label information or reliable data, retaining source/serving metadata.
* Add clearer personal exercise preference controls (machines/free weights) without making programme choice random.
* Improve food-photo serving-size confirmation rather than pretending that an image can always estimate portions exactly.

