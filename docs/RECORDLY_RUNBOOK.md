# Recordly Runbook — Demo Recording

Tool: [Recordly](https://github.com/webadderallorg/Recordly) (AGPL-3.0), prebuilt Windows
build from `github.com/webadderallorg/Recordly/releases`. Used as a local capture/editor
tool only; no Recordly code ships in this repo.

**Lynkr is not used.** It is an LLM gateway for AI coding tools (token compression,
provider tier routing) with no capture or editing capability. It is irrelevant to video
production and proxies development prompts to third-party providers, which we do not
want in a Google AI submission.

---

## ⚠️ Order of operations — do not reorder

```
1. Fix deck copy  →  2. Deploy  →  3. Record  →  4. Re-export
```

The shot list opens with deck slide 2 on screen for the first 25 seconds. Any error in
slide copy is **burned into the video permanently**. Record only after the deck is final.

Record the fallback takes first. Never debug on camera.

---

## 0. Prerequisites

Check your Windows build (`winver`): Recordly's native Windows Graphics Capture helper
needs **Windows 10 build 19041 (20H1) or later** for clean cursor hiding. On older builds
it falls back to Electron capture and the real cursor stays visible in the export, which
reads as amateur.

```
flutter build web                 # app/build/web
firebase deploy --only hosting    # live link
```

Verify the deployed link **in a private/incognito window** before recording. Judges will.

---

## 1. Frame styling — apply once

| Setting | Value | Why |
|---|---|---|
| Background | Solid dark or subtle gradient | Stops the desktop wallpaper bleeding into frame |
| Padding | 40–60 px | Reads as deliberate, not a raw screengrab |
| Rounded corners | On | Instantly reads as a product demo |
| Aspect ratio | 16:9 | Judge-viewer standard |
| Drop shadow | On, soft | Depth separation from background |
| **Webcam bubble** | Bottom-right preset | Largest single trust lever available |
| Export | MP4, highest quality | Brief requires 3–5 min; 1080p |

The webcam bubble matters more than any effect below. Judges rate presenter presence.
Record a take with it visible and keep it as the fallback if a take goes wrong.

---

## 2. Per-beat treatment

| Time | Beat | Recordly treatment |
|---|---|---|
| 0:00–0:25 | Hook — problem slide | Speed region ×3 on any slide-build animation |
| 0:25–0:50 | Voice input, Tamil | **Manual zoom region on the risk card.** Cursor click-bounce on the mic tap. |
| 0:50–1:15 | Firebase console reveal | Speed region ×4 on the RTDB load. Trim the dead air. |
| **1:15–1:45** | **AI reveal — the money shot** | **Slowest, longest-held zoom in the video.** Auto-zoom will under-sell this beat; place a manual zoom region on the risk card and let it sit. This is the frame judges remember. |
| 1:45–2:15 | Redistribution | Click-bounce on **Approve**; cursor smoothing so the eye follows the state change |
| 2:15–2:35 | Alert fires | Zoom on the `alertLog` entry as it appears |
| 2:35–3:00 | Validation | Static. Let `validation_chart.svg` breathe. |
| 3:00–3:15 | Close | No zoom. Webcam bubble full attention. |

**Say "7-day," not "30-day."** The model forecasts a 7-day horizon
(`HORIZON_DAYS = 7` in `functions/index.js`; 7-day holdout framing in `backtest.py`).
The old deck claimed 30-day advance warning on one slide while every other artefact said
7 — that contradiction is fixed everywhere, and the video must match.

**Quote 71%, not 99% or 65%.** Deck slide 8 quotes the nearest-neighbour figure. If you
mention impact on camera, use the same number and say "simulated."

---

## 3. Capture checklist

```
□ phone on Wi-Fi, charged
□ Flutter web running locally (or the deployed link open)
□ Firebase console open on a second display
□ microphone tested — no room echo
□ screen recorder at 1080p
□ all other tabs and windows closed
□ notifications / Do Not Disturb ON
```

## 4. Fallback takes — shoot these BEFORE the live takes

- **Voice fails live?** Tap mic → recognition runs → show the manual-entry dialog labelled
  "connectivity dropped" → type "Paracetamol 50" → same downstream shots.
- **Firebase slow?** Use demo mode, narrated as a pre-recorded run.
- **Vertex unreachable?** This is already designed for — narrate the offline fallback
  as a feature ("same feature contract, no connectivity dependency"). Do not debug on camera.

## 5. After recording

1. Save the `.recordly` project file — you will re-export at least once.
2. Re-watch once at 1× before exporting. Check: no clipped text, no dead air over 2 s,
   the AI-reveal beat is legible without narration.
3. Export MP4 at highest quality.
4. Upload unlisted. Confirm the submission portal accepts a link vs. requiring a direct
   file upload **before** you assume a link is fine.
