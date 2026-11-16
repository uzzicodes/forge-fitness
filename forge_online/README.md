# FORGE

An iPhone Home Screen web app for nutrition, strength training and progress. Hosted on Sites with Cloudflare Workers and D1. No running home computer is required.

Personal records: each exercise card shows its heaviest checked set and latest earlier session for that exercise. Progress → Personal records opens the full list; tapping a PR shows set/date history. Records derive from saved sessions, including completed sets retained after swaps, and recalculate after corrections, reopening and deletions. Historical views stop at that day and future-dated logs never count. Equal loads compare reps. Assisted pull-ups favor lower assistance (including zero); bodyweight reps/holds and added-load records stay separate. Zero load is not treated as a weighted-lift PR. PRs add no extra XP and are not estimated one-rep maxima. Barbell loads are totals and dumbbell loads are per dumbbell; only compare the same machine/setup. Existing account/guest storage isolation and cloud sync apply automatically.

The training rotation remains stable across weeks and already varies movements across sessions. Suitable exercise swaps remain available. Repeating key lifts makes the saved-set comparisons useful; the app does not randomly replace exercises each Monday. Design reference: [ACSM’s 2026 resistance-training guidance](https://acsm.org/resistance-training-guidelines-update-2026/) emphasizes consistency and individualization and does not require complex variation for general adult training. No universal best exercise or weekly PR is promised.

Guest access: choose **Continue without signing in** at `/`, or open `/fitness/?mode=guest`. Profiles, meals, water, workouts, habits, ranks, weekly scoring, saved recipes and packet labels use a separate device storage namespace. The choice persists on subsequent `/fitness/` launches. Guest text estimates, food references, recipe calculations and bounded Open Food Facts lookup use only explicit public `/api/guest/` routes; no personal server records or AI-provider requests are authorized by guest mode. The small photo matcher and barcode decoder still run on-device. Gemini/Groq require a signed-in account. `/fitness/?mode=account` selects the separate cloud profile; guest records are preserved and never silently uploaded. Guest backups include device recipes/labels. Use the same browser or installed app, since iOS storage may differ between them.

Daily check-in is available from Today, Daily Fuel and the rank card. It shows logged meals, personal protein/calorie/water progress, and practical next steps. Past days use saved weekly targets and advise correcting actual records rather than making up old food or water totals.

Weekly accountability begins the Monday after activation. Weeks run Monday–Sunday using a synced fixed account UTC offset; Saturday/Sunday make-up sessions count, with one completed workout per date. Weekly plans snapshot the profile’s 2–5-session goal and personal fuel targets. Target changes affect the next week; a recovery switch exempts only the selected open week. After a scored week closes: 25 XP per missing workout, 5 per protein-gap day, 5 per day outside the ±10% calorie range, and 3 per water-gap day. Weekly loss is capped at 120 XP and available balance at that week’s end, without debt against future awards. Unlogged days count as incomplete. The derived chronological ledger avoids duplicate deductions and recalculates corrected records. This is personal accountability, not a tamper-proof competitive leaderboard.

- Sign in with ChatGPT for private profile, meals, workouts, attendance, water, weight and recipes.
- Choose 2–5 training weekdays. Completing a session advances the rotation; skipped and recovery days preserve the next session. Five days uses push/pull/legs/upper/lower.
- Write one message such as “I ate 3 boiled eggs”, review the estimate and confirm. Food photos and extra details are optional. The app calculates 232.5 kcal and 18.9 g protein for three assumed large boiled eggs.
- 7,793 USDA SR Legacy food references retain all available nutrient fields and reference servings, alongside 98 common Pakistani foods and explicitly modeled recipes. Local recipes show oil, sugar, cooked yield and serving assumptions. Unknown dishes and brands require clarification.
- Lean & defined is the default goal: estimated maintenance calories and balanced training, with incline chest and lateral-raise emphasis for the full-gym five-day plan. Existing goals and completed workouts remain supported.
- Hydration sits in Daily Fuel with an editable drink target, metric text logging and quick amounts. Optional habits support daily checks, per-habit/activity streaks and consistency ranks. XP does not increase for extra food or water consumption.
- All 22 exercises have real video sources: six short self-hosted H.264 CC BY-SA clips and sixteen verified creator-hosted embeds, with attribution and fallback source links.
- An optional 9.4 MB MobileNetV2 Food101 classifier suggests four of 101 supported dishes in the browser and withholds low-confidence results. It cannot measure portions or reliably identify unsupported foods. Confirm food and grams before saving. Food search needs no AI key.
- Gemini 3.5 Flash-Lite handles photos and unclear messages when AI is enabled, with a visible Google-processing notice before the request. The owner-provided shared key is a Sites runtime secret and has a combined 20-attempt daily cap; private per-account keys are encrypted and have their own 20-attempt cap. No automatic paid-model fallback or billing activation. Eligible API free tiers are separate from Gemini app subscriptions. A real public-food photo request passed.
- Meal photos are never archived. Estimating with AI sends the photo to Google after the visible processing notice. Without connected AI, the small food matcher runs on the device.
- After Offline ready, cached files support offline manual logging and training. Record edits queue and sync on reconnect; Settings has Sync now. Food search requires internet. Clearing browser storage before syncing can lose queued edits.

The Flutter source is in `../forge_fitness`; `flutter-src/` is its reproducible source snapshot. Build web with base `/fitness/`, `FORGE_HOSTED=true`, `--no-web-resources-cdn`, then run `node scripts/prepare-flutter.mjs`. Build/package/publish through the Sites skill helpers. Keep the existing Site ID and runtime secrets outside source.

Run Flutter analysis/tests from `../forge_fitness`, `node --test tests/*.test.mjs` and `npx tsc --noEmit`. Browser QA uses headless Edge and the loopback preview database; production is not seeded with test profiles or meals. Physical iPhone/Safari installation is not claimed as tested. Drizzle migrations contain schema only. `/api/catalog/bootstrap` imports only public food references; all personal endpoints require sign-in. Browser fixture reversions use exact client/time ownership and conditional clocks, preserving concurrent user edits.

The browser model was exported from the publisher's trained checkpoint using `scripts/export-food-model.py`, with weight-only loading. Provenance and checksums are in `public/vision/model-info.json`. Build-only CPU conversion tools are not part of the deployed app. The publisher's original ONNX export was rejected after checking its degenerate output range; the replacement passes a checksum/logit regression test and recognizes the held-out beignets sample in browser QA.

Nutrition: [USDA FoodData Central SR Legacy](https://fdc.nal.usda.gov/download-datasets/). Classifier: [AlexKoff88/mobilenet_v2_food101](https://huggingface.co/AlexKoff88/mobilenet_v2_food101), Apache 2.0; labels ETHZ Food101. ONNX Runtime Web 1.20.1 is MIT. Notices are in `public/vision/`.

## Development scaffold reference

A clean full-stack starter running on [vinext](https://github.com/cloudflare/vinext), with optional Cloudflare D1 and Drizzle support.

## Prerequisites

- Node.js `>=22.13.0`
- Portable: Windows, macOS, or Linux; no Bash required
- Managed Linux: managed Linux runtime with Bash, `flock`, `curl`, `sha256sum`, and GNU `timeout`
- Git and `tar` (including Windows `tar.exe`) are required for publishing; portable publication does not require Bash

## Sites Lifecycle

The Sites initializer copies the shared starter and selects managed-linux only when `SITES_MANAGED_LINUX_CONTAINER=1`; otherwise it selects portable. It saves the selection only in ignored `.sites-runtime/execution-profile.json`. Both profiles copy/configure first, then use the plugin's separate `install-dependencies.mjs` step to measure installation independently. Edit source under `app/` and follow the Sites skill for installation, preview, builds, and publishing.

Run `node <plugin-root>/scripts/configure-execution-profile.mjs` only when the profile is unknown for the current checkout and environment. Profile changes do not alter tracked source or require reinstalling otherwise-valid dependencies; restart an existing preview to use the new selection. Do not commit or upload `.sites-runtime/`.

This starter does not use `wrangler.jsonc`.

Publish archives outside the source checkout or under its ignored `outputs/` directory. Local `.env*`, `.dev.vars*`, TypeScript build state, and tool runtime directories are ignored; keep the hosting manifest, migrations, and authored scripts in source control.

`install:ci` runs `npm ci` once against the shared lockfile, disables parent-workspace discovery, and includes required dev/optional dependencies despite production/omit settings. Sharp defaults to prebuilt binaries unless explicitly configured otherwise. Do not overlap installers.

- **Portable:** Preserve host HOME, npm cache, registry, proxy, temporary paths, retry/concurrency settings, and lifecycle-script policy. Use `--prefer-offline --no-audit --no-fund`.
- **Managed Linux:** Use the existing project-local HOME/cache/tmp setup and Linux install lock, tarball preflight, and timeout. Restore the image-seeded npm cache only when its lockfile hash matches; retain network fallback. Builds keep their existing timeout. These helpers are not invoked by the portable profile.

`scripts/sites-env.mjs` preserves the caller's HOME, npm cache, proxy, XDG, and temporary-directory configuration while defaulting Wrangler and Miniflare state to the checkout. If npm reports an unwritable cache, select a writable path with `npm_config_cache` for that install. The `dev` and `start` scripts also keep Wrangler logs inside the checkout. Generated `.sites-runtime/` and `.wrangler/` directories are disposable and ignored by Git.

On portable, `npm run dev` uses `vinext dev` with HMR, starting at port 5173. Vinext records the running server in ignored `.vinext/` state, rejects an ordinary duplicate launch, and recovers stale state after a stopped process; exactly simultaneous starts can race. Pass `--port <port>` or `--hostname <host>` after `npm run dev --` when needed; keep portable previews on loopback.

For managed Linux browser QA, follow the Sites skill's managed preview reference. The daemon runs the project's Vite dev script with `--host 0.0.0.0 --port 4173 --strictPort`; use the CLI's returned URL. The ignored local profile survives the daemon's cleared environment.

The portable profile simulates ChatGPT sign-in only for loopback development requests. Visit `/signin-with-chatgpt?return_to=/` to sign in as `local_seedy` (`seedy@sites.test`, display name `Seedy`) and `/signout-with-chatgpt?return_to=/` to sign out. The development cookie preserves that identity across server restarts. Mock auth is disabled in the managed-linux profile and is not included in production builds; hosted authentication remains dispatch-owned.

The Worker uses `vinext/server/fetch-handler`, including Vinext's config-aware image handling. After building, `npm start` runs that Worker locally through Wrangler on `127.0.0.1`, sharing `.wrangler/state` with dev preview and local D1 migrations; it does not deploy the site or simulate sign-in. Use the URL printed by the server. Pass `npm start -- --port <port>` to select a different built-preview port.

Local previews use Miniflare's placeholder `Request.cf` metadata without a network lookup. Set `CLOUDFLARE_CF_FETCH_ENABLED=true` to opt into fetching preview metadata; this setting does not change hosted request metadata.

Local tool usage metrics are disabled by default. Set `WRANGLER_SEND_METRICS=true` to opt in.

## Included Shape

- edit site code under `app/`
- `app/chatgpt-auth.ts` provides optional dispatch-owned ChatGPT sign-in helpers
- `.openai/hosting.json` declares optional Sites D1 and R2 bindings
- `vite.config.ts` simulates declared bindings for local development
- `worker/index.ts` is the production Worker entrypoint and preserves request-scoped connector bindings
- `scripts/vite/` contains the maintained Vite integrations and the vendored Sites plugin license
- `scripts/connector-preview/` contains the local connector preview Worker and session helpers
- the remaining `scripts/` files select execution profiles and run installation, development, and builds; the plugin's helpers orchestrate the Sites lifecycle
- `dist/` contains generated deployment output; `.vinext/`, `.wrangler/`, and `.sites-runtime/` contain ignored local tool state
- `db/index.ts` reads the D1 binding from the Cloudflare Worker environment
- `db/schema.ts` starts intentionally empty
- `@cloudflare/workers-types` provides Worker types; `cloudflare-env.d.ts` declares optional `DB`/`BUCKET` bindings—update these declarations if binding names change
- `examples/d1/` contains an optional D1 example surface
- `drizzle.config.ts` supports local migration generation when needed

## Workspace Auth Headers

Signed-in visitors receive both `oai-authenticated-user-id` and `oai-authenticated-user-email`. Private Sites require every visitor to sign in; public Sites may also have anonymous visitors, for whom neither header is present.

The user ID is stable for the same user on the same Site and different across Sites. Use it as the durable user key; use email and name for display or contact purposes.

SIWC-authenticated workspace sites may also receive `oai-authenticated-user-full-name` when the user's SIWC profile has a non-empty `name` claim. The full-name value is percent-encoded UTF-8 and is accompanied by `oai-authenticated-user-full-name-encoding: percent-encoded-utf-8`.

Treat the full name as optional and fall back to email when it is absent:

```tsx
import { headers } from "next/headers";

export default async function Home() {
  const requestHeaders = await headers();
  const userId = requestHeaders.get("oai-authenticated-user-id");
  const email = requestHeaders.get("oai-authenticated-user-email");
  const encodedFullName = requestHeaders.get("oai-authenticated-user-full-name");
  const fullName =
    encodedFullName &&
    requestHeaders.get("oai-authenticated-user-full-name-encoding") ===
      "percent-encoded-utf-8"
      ? decodeURIComponent(encodedFullName)
      : null;

  const displayName = fullName ?? email;
  // ...
}
```

## Optional Dispatch-Owned ChatGPT Sign-In

Import the ready-to-use helpers from `app/chatgpt-auth.ts` when the site needs optional or required ChatGPT sign-in:

- Use `getChatGPTUser()` for optional signed-in UI.
- Use the returned `userId` as the stable user key for user-owned records; do not use email as a durable identifier.
- Use `requireChatGPTUser(returnTo)` for server-rendered pages that should send anonymous visitors through Sign in with ChatGPT.
- In a Server Component, start sign-in with `<a href={chatGPTSignInPath(returnTo)} target="_top">`. The auth helper module is server-only; do not import it into a Client Component.
- Do not use `fetch`, XHR, a client-side router, or a framework link that can prefetch the sign-in route. SIWC must start as a top-level navigation.
- Never request the AuthAPI authorization endpoint directly. The dispatch-owned `/signin-with-chatgpt` route must start the SIWC flow.
- Use `chatGPTSignOutPath(returnTo)` for browser sign-out links or actions.
- Pass a same-origin relative `returnTo` path for the destination after sign-in or sign-out. The helper validates and safely encodes it.
- Mark protected pages with `export const dynamic = "force-dynamic"` because they depend on per-request identity headers.

Dispatch owns `/signin-with-chatgpt`, `/signout-with-chatgpt`, `/callback`, the OAuth cookies, and identity header injection. Do not implement app routes for those reserved paths. Routes that do not import and call the helper remain anonymous-compatible.

SIWC establishes identity only; it does not prove workspace membership. Use the Sites hosting platform's access policy controls for workspace-wide restrictions, or enforce explicit server-side membership or allowlist checks.

Use SIWC for account pages, user-specific dashboards, saved records, and write actions tied to the current ChatGPT user. Leave public content anonymous.

## Local D1 migrations

For a D1-backed local preview, generate SQL with `npm run db:generate`. Build once through the Sites skill's build entrypoint (or `npm run build` for standalone use) to generate `dist/server/wrangler.json`, rebuilding if bindings change. From the project root, apply each pending migration in order:

```sh
node --import ./scripts/sites-env.mjs ./node_modules/wrangler/bin/wrangler.js d1 execute DB --local --config dist/server/wrangler.json --persist-to .wrangler/state --file drizzle/0000_example.sql
```

Replace the filename with the pending migration and `DB` with your D1 binding name if different. Use `.wrangler/state`, not `.wrangler/state/v3`; Wrangler adds the versioned directories. Do not replay migrations already applied locally. This updates only the preview database; publishing applies production migrations separately.

## Diagnostic Commands

- `npm run install:ci`: perform the one locked dependency install
- `npm run dev`: start the Vite/Vinext development server
- `npm run build`: build the deployable Sites artifact
- `npm run start`: preview the built Worker locally with D1/R2 support
- `npm run db:generate`: generate Drizzle migrations after schema changes

When using the Sites plugin, follow its skill instructions for installation, builds, and publishing. These npm commands remain available for standalone use.

The portable build runs Vinext directly without a host `timeout` command. The managed-linux build uses `scripts/build-verified.sh` and its existing `SITES_BUILD_TIMEOUT` setting.

## Learn More

- [vinext Documentation](https://github.com/cloudflare/vinext)
- [Drizzle D1 Guide](https://orm.drizzle.team/docs/get-started/d1-new)
