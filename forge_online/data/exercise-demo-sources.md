# FORGE exercise demonstration assets

Reviewed 27 October 2026. `exercise-demos.json` covers all 22 IDs in the FORGE exercise library. It contains six local H.264 demonstrations and sixteen original-provider YouTube embeds. No generic stick figure is necessary.

## Local clips and extracted posters

The wger public REST API is documented at <https://wger.readthedocs.io/en/latest/api/api.html>. The API's per-video records explicitly declare license ID 2, Creative Commons Attribution-ShareAlike 4.0, with author Goulart. License: <https://creativecommons.org/licenses/by-sa/4.0/>. Source URLs, original media URLs and modifications are retained per exercise in the manifest.

| FORGE exercise | wger video ID | Source exercise | Local file |
| --- | ---: | --- | --- |
| Barbell bench press | 21 | 73 Bench Press | `/demos/bench.mp4` |
| Dumbbell lateral raise | 6 | 348 Lateral Raises | `/demos/lateral.mp4` |
| Dumbbell triceps extension | 57 | 211 Dumbbell Triceps Extension | `/demos/triceps.mp4` |
| Seated cable row | 1 | 512 Rowing seated, narrow grip | `/demos/row.mp4` |
| Dumbbell shoulder press | 12 | 567 Shoulder Press, Dumbbells | `/demos/shoulder.mp4` |
| Dumbbell curl | 48 | 92 Biceps Curls With Dumbbell | `/demos/curl.mp4` |

The clips have been trimmed to ten seconds (bench: fifteen seconds), resized and re-encoded as H.264 with sound removed. Each JPG poster is a frame extracted from its corresponding clip. The derivative clips and posters remain CC BY-SA 4.0. Display the author, source link, license link and modification statement with the player. That asset license does not by itself license the app's unrelated code or other content.

All six local clips are below 2 MB. Combined video and poster payload is approximately 5.2 MB. Posters were visually reviewed: the person, equipment and movement match the exercise. The RDL and calf-machine clips in wger were deliberately not substituted for the plan's dumbbell RDL and bodyweight calf raise.

To recreate a clip from the manifest's `originalVideoUrl`, use a video conversion tool with this transformation: `-t 10 -an -vf fps=20,scale=640:-2 -c:v libx264 -preset veryfast -crf 24 -movflags +faststart`. Keep attribution and the modification statement. The conversion tool is build-only; it is not required by the hosted app or phone.

## Original-provider embeds

The sixteen remaining demonstrations are hosted by their creators, including NASM, OPEX Fitness, Nuffield Health, AskDoctorJo and Howcast. Each was verified through YouTube's oEmbed endpoint with HTTP 200, matching exercise title and author; results are in `exercise-demo-embed-verification.json`. NASM tutorials were also checked against the corresponding official NASM exercise-library pages. Nuffield's single-arm row appears on its official dumbbell-exercise article. Other sources link to the creator's own YouTube page or Howcast's own page.

These clips are **embed only**: no copyrighted YouTube video copy is bundled. Use the manifest's privacy-enhanced `youtube-nocookie.com` URL in a standard player iframe after a Play tap, keep player controls and creator attribution, and offer `watchUrl` as a fallback. Thumbnails are provider-supplied external URLs, not copied into the public assets. Third-party playback needs internet and can vary by region or provider policy. An oEmbed check confirms availability, not an unrestricted redistribution license or guaranteed regional playback.

The `pike` FORGE ID is correctly mapped to **incline push-up**, as named in the current app, rather than to the unrelated pike push-up. The floor press is an actual floor-press tutorial, rather than a bench-press clip.

The calf-raise and goblet-squat fallback images initially researched were removed from public assets after suitable creator-hosted videos were found.


## Incline dumbbell bench press addition

The new inclinedbpress ID uses OPEX Fitness’s Incline Dumbbell Bench Press tutorial: https://www.youtube.com/watch?v=jMQA3XtJSgo. YouTube oEmbed returned HTTP 200 with exactly that title and author OPEX Fitness. This is the incline, two-dumbbell bench-press variation, rather than flat pressing, incline barbell pressing or single-arm pressing. It is creator-hosted and embed-only; no video download was made.
