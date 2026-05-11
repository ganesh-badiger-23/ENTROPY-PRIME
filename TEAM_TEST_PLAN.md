# ENTROPY PRIME — TEAM TEST PLAN

This note is for Ganesh, Ved, and Vivek.

> **Ganesh — Test 1 completed on 2026-05-10.**  
> All 4 steps passed. Full details in `TEST_RESULTS_GANESH.md`.  
> Automated: `42 / 42 tests passed` (`pytest tests/test_stage1_biometric.py -v`).

---

## 1) How to start the app

1. Open a terminal in the project folder.
2. Run `.\start.bat` (Windows) or `bash start.sh` (Mac/Linux).
3. Wait until both services are ready:
   - Frontend: `http://localhost:3000`
   - Backend API docs: `http://localhost:8000/docs`
4. If anything fails, start them separately:
   - Frontend: `npm run dev`
   - Backend: `python -m uvicorn main:app --port 8000 --reload` (run from the `backend/` folder)

---

## 2) What to test

### Test 1: First-user typing flow and re-authentication (Ganesh)

This is the main test. Follow these steps exactly.

**Step 1 — Open the app and log in**

Open `http://localhost:3000` in the browser. Type your email and password and click Authenticate.

**Step 2 — Watch the baseline banner**

After login, go to the Dashboard or Threat Intel page. Look for the amber-coloured banner at the top of the screen. It should say something like:

> `BASELINE MODE — type normally to build your pattern. (0 / 30)`

This means the system is in **learning mode**. It is collecting your typing samples. Detection is OFF. No false alarms will fire at this stage.

**Step 3 — Build the baseline by typing normally**

Type in the search fields, navigate between pages, or go back to the login page and type in the password field. The number next to `BASELINE MODE` will count up (0, 5, 10...).

When the count reaches 30, the banner turns **green** and says:

> `PATTERN ACTIVE — your typing baseline is saved. Suspicious changes will trigger re-auth.`

This means the system has learned your pattern. Detection is now ON.

**Step 4 — Simulate suspicious typing (the test)**

Open the browser Developer Tools (F12 → Console tab). Paste and run this snippet:

```js
// Inject 50 "robot-speed" keystrokes to simulate fast random typing.
// Each keystroke has a 10ms dwell (very fast, humans average 80-150ms).
const ep = window.__EP_CLIENT__
if (!ep) { console.error('Biometrics engine not found'); }
else {
  const now = performance.now()
  for (let i = 0; i < 50; i++) {
    ep.keyboard._events.push({
      dwell: 10,      // 10ms dwell = robot speed
      flight: 5,      // 5ms between keys = robot speed
      ts: now + i * 15,
      bigramRatio: Math.random() * 2  // random bigram = no pattern
    })
  }
  console.log('[TEST] Injected 50 rapid-typing events. Wait ~3 seconds for the warning.')
}
```

**Step 5 — Watch for the re-auth warning**

Within 3–5 seconds (the live-eval loop runs every 1.5s), a **red banner** should appear at the top of the page:

> `⚠ SUSPICIOUS TYPING DETECTED`
> `Behavioral drift detected (score: X.XX, trust: XX%)`

Two buttons appear: **RE-AUTHENTICATE NOW** and **Dismiss**.

**Step 6 — Click "Re-Authenticate Now"**

The app logs you out and takes you back to the login page. The login page shows a red alert:

> `⚠ SUSPICIOUS ACTIVITY DETECTED — RE-AUTHENTICATION REQUIRED`

**Step 7 — Verify in the console and backend logs**

- Browser console should show: `[AuthContext] Re-auth required: Behavioral drift detected...`
- Backend terminal should show: `[TypingSample] user=... ACTIVE drift=X.XX suspicious=True action=reauth`

**Step 8 — Test the API directly (optional, no browser needed)**

Get your session token from the app (localStorage: `ep_token`) and run:

```bash
# Learning phase (should say "learning")
curl -X POST http://localhost:8000/biometric/typing-sample \
  -H "X-Session-Token: YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"feature_vector": [0.3,0.2,0,0,0,0.5,0,0.5], "sample_count": 5, "baseline_ready": false, "drift_score": 0.0}'

# Active phase, normal typing (should say "ok")
curl -X POST http://localhost:8000/biometric/typing-sample \
  -H "X-Session-Token: YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"feature_vector": [0.3,0.2,0,0,0,0.5,0,0.5], "sample_count": 40, "baseline_ready": true, "drift_score": 0.8}'

# Active phase, rapid typing (should say "reauth" with suspicious=true)
curl -X POST http://localhost:8000/biometric/typing-sample \
  -H "X-Session-Token: YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"feature_vector": [0.02,0.01,0,0,0,0.9,0,0.5], "sample_count": 40, "baseline_ready": true, "drift_score": 3.5}'
```

**Run the automated backend tests:**
```bash
cd backend
python -m pytest tests/test_stage1_biometric.py -v
```
All tests should pass, including the three new classes:
- `TestBaselinePhase`
- `TestSuspiciousTypingDetection`
- `TestReAuthFlow`

---

### Test 2: Continuous monitoring while logged in (Ved)

- Log in and stay on the Dashboard page.
- Keep the app idle for a few minutes.
- The watchdog heartbeat fires every 30 seconds and sends a request to `/session/verify`.
- Ask another person to start typing on the same keyboard.
- After 1–2 heartbeat cycles (30–60 seconds), the re-auth banner should appear.
- If it does not appear, check the browser console for `[AuthContext] Heartbeat` messages.

**What to check:**
- Does the drift score increase when a different person types?
- Does the re-auth banner appear at the right time (not too early, not too late)?
- Does clicking "Dismiss" clear the banner? Does it come back after the next heartbeat if drift continues?

**Suggested improvement:** If the heartbeat interval (currently 30s) is too slow for the demo, reduce it to 10s in `AuthContext.jsx` line where `setInterval(..., 30_000)` appears.

---

### Test 3: Honeypot testing with a bot (Vivek)

- Keep the real app running.
- In a second terminal, run the bot simulation script:

```bash
# Simple bot script — fires 20 fast login attempts to /score
python -c "
import requests, time
for i in range(20):
    r = requests.post('http://localhost:8000/score', json={
        'theta': 0.03,
        'h_exp': 0.9,
        'server_load': 0.4,
        'user_agent': 'BotScript/1.0',
        'latent_vector': [0.0] * 32
    })
    print(i, r.status_code, r.json().get('shadow_mode'), r.json().get('humanity_score'))
    time.sleep(0.5)
"
```

- Watch the Threat Intel page in the real app — bot signatures should appear in the table within 10 seconds.
- Each row should show `shadow_mode: true` and a theta score near 0%.
- The bot receives a fake session token instead of a real one.

---

## 3) Division of work

### Ganesh — First-user typing flow
Follow **Test 1** above completely. Write down:
- What the banner shows at each step.
- Whether the red warning appeared after the console snippet.
- Whether re-auth correctly returned you to the login page.
- Any place where the behaviour seemed too slow, too strict, or confusing.

### Ved — Continuous monitoring
Follow **Test 2** above. Write down:
- How long it took for drift to be detected.
- Whether the dismiss button worked correctly.
- Whether the heartbeat logged anything useful.

### Vivek — Honeypot and bot test
Follow **Test 3** above. Write down:
- How many bot signatures appeared in the Threat Intel table.
- Whether all entries showed `shadow_mode: true`.
- Any errors in the backend terminal.

---

## 4) What to improve after testing

- Make the typing detection more reliable for edge cases (slow typists, mobile keyboards).
- Make re-authentication happen faster when behaviour changes (reduce heartbeat from 30s to 10s).
- Add a visible "why was I flagged?" reason to the re-auth banner (already implemented — verify the reason text is clear).
- Add simple logs so we can see exactly why the app made each decision.
- Keep the system easy to test again later.

---

## 5) Final goal

Build a full system where:
- Normal users build their baseline in ~30 keystrokes.
- Suspicious typing (very fast, random) is detected and triggers re-auth.
- A different person typing causes re-auth after 1–2 heartbeat cycles.
- Bots are trapped in the honeypot and never see real data.
- The app monitors the user all the time, not just at login.