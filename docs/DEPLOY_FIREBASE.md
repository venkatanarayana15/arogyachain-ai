# Firebase Hosting Deploy — Step by Step

Target: `https://arogyachain-ai.web.app` (live link = submission artifact #5)

Everything is already in place. `firebase.json` points at `app/build/web`, and
`.firebaserc` names the project `arogyachain-ai`. You only need to authenticate
and deploy.

---

## Before you start — one decision

Your app currently runs in **demo mode**: it ships with 8 PHCs of mock data
rendered from `app/lib/models.dart` and shows a `DEMO MODE` badge.

| Option | Time | What you get |
|---|---|---|
| **A. Deploy as-is** ✅ | ~10 min | Live link, works immediately, honest badge |
| B. Wire live Firebase | ~1–2 hr | Live RTDB, but needs seeding + functions + `firebase_options.dart` |

**Deploy A now.** A working link beats a broken ambitious one with hours left.
You can always deploy B afterwards — redeploying is one command.

---

## Step 1 — Authenticate (one-time)

```powershell
npx firebase-tools login
```

A browser opens → sign in with the Google account you want the project under →
paste the authorization code back into the terminal.

> Don't paste that code into chat. It's a credential.

**Verify:**
```powershell
npx firebase-tools login:list
```
You should see your account listed.

---

## Step 2 — Confirm the project exists

```powershell
npx firebase-tools projects:list
```

Look for `arogyachain-ai`.

**If it's not listed**, create it before deploying:
```powershell
npx firebase-tools projects:create arogyachain-ai --display-name "ArogyaChain AI"
```

> A Firebase project and a GitHub repo are different things. Creating one does not
> create the other.

---

## Step 3 — Rebuild (so you deploy what's on disk now)

```powershell
cd D:\Hackathons\build-with-ai\app
flutter build web --release
cd ..
```

Wait for `√ Built build\web`.

---

## Step 4 — Deploy

```powershell
npx firebase-tools deploy --only hosting
```

First run takes a few minutes. You'll see a URL like:

```
✔ Deploy complete!
Hosting Site: arogyachain-ai [https://arogyachain-ai.firebaseapp.com]
```

---

## Step 5 — Verify as an anonymous judge would

This is the step people skip. **Open a private/incognito window** and load the
URL. You are testing: "does this work for someone who has never seen this
project and is not logged in?"

Check all four:

| Check | Expected |
|---|---|
| Page loads | Green ArogyaChain AI header, **no** login prompt |
| Badge | `DEMO MODE` visible top-right — this is intentional honesty |
| Risk cards | Paracetamol ~91%, Amoxicillin ~96%, ORS ~8% |
| Manual entry | Type `Paracetamol 50` → press `+` → risk climbs, transfer appears |

Also test on your **phone** — judges will open the link on a phone.

If the page is blank: hard-refresh (`Ctrl+Shift+R`). Flutter's service worker
caches aggressively and a stale cached bundle renders blank.

---

## Step 6 — Record the deployed URL

Update the deck so the link is baked into the PDF:

```powershell
# build_deck.py already auto-detects from .firebaserc — just verify
python build_deck.py
```

Confirm it prints your live URL:
```
[i] live link  : https://arogyachain-ai.web.app
```

Then commit the refreshed PDF:
```powershell
git add -A
git commit -m "Refresh deck with verified live link"
git push
```

---

## Redeploying later

After any code change:
```powershell
cd app; flutter build web --release; cd ..
npx firebase-tools deploy --only hosting
```
One command. Everything is tracked.

---

## If something fails

| Error | Cause | Fix |
|---|---|---|
| `Authentication required` | Not logged in | Re-run Step 1 |
| `Project not found` | Project doesn't exist | Create it (Step 2) |
| `Permission denied` | Wrong Google account | `npx firebase-tools login` → sign out, sign in with the right one |
| Blank page on the deployed URL | Stale service-worker cache | Hard-refresh; if it persists, redeploy — hosting revalidates |
| `Cannot find module firebase-tools` | npx cache | `npx firebase-tools@latest deploy --only hosting` |

---

## Optional — live Firebase (only if hours remain)

This upgrades the demo from mock data to a real Realtime Database.

```powershell
cd app
flutter pub global activate flutterfire_cli
flutterfire configure --project=arogyachain-ai      # generates firebase_options.dart
cd ..
node scripts/seed_rtdb.js                            # loads data/inventory_seed.json
npx firebase-tools deploy --only functions,database
cd app; flutter build web --release; cd ..
npx firebase-tools deploy --only hosting
```

**Risk:** `scripts/seed_rtdb.js` needs `serviceAccountKey.json` in the repo root
(gitignored). If you run out of time mid-way you can end up with a half-wired
app. **Deploy the demo-mode version first and confirm it works.** Only then
attempt this.
