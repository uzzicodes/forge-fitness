# FORGE Fitness & Fuel — AI Workout & Nutrition Tracker

> A full-stack fitness app I use for my own gym training: workout plans, personal records, meal & water logging with AI nutrition estimates, and weekly accountability scoring. Installable on iPhone as a Home Screen web app.

## Highlights
- **Smart training rotation** – 2–5 day plans (push/pull/legs/upper/lower), swaps, recovery days, per-exercise **personal-record tracking** with trend charts.
- **AI meal logging** – type "I ate 3 boiled eggs" or snap a photo; LLM estimate (Gemini / Groq, user's own key) is confirmed before saving.
- **Nutrition database** – 7,793 USDA SR Legacy foods + 98 common Pakistani dishes with recipe-level assumptions; Open Food Facts barcode lookup.
- **Weekly accountability** – XP, ranks and streaks with a deterministic ledger that recalculates after corrections.
- **Guest mode & cloud sync** – isolated on-device storage for guests; signed-in accounts sync through Cloudflare D1.
- **Security** – no shared API keys; secrets only via environment variables; certificate keys never committed.

## Tech stack
| Part | Tech |
|---|---|
| Mobile app | **Flutter / Dart** (`forge_fitness/`) with a local Node server for LAN + offline PWA |
| Web app & API | **Next.js, TypeScript, Tailwind**, Drizzle ORM (`forge_online/`) |
| Hosting | **Cloudflare Workers + D1** (SQLite) |
| AI | Gemini / Groq / OpenAI APIs |
| Testing | Unit + UI tests, QA scripts |

## Project layout
```
forge_fitness/   Flutter app + local server (Windows / iPhone PWA)
forge_online/    Next.js app, Cloudflare Worker API, D1 schema & migrations
```

---
Built by **Muhammad Uzair** · [Portfolio](https://uzzicodes.github.io) · [LinkedIn](https://www.linkedin.com/in/muhammad-uzair-03b885355/)
