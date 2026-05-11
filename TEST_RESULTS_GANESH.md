**ENTROPY PRIME — TEST RESULTS REPORT**
Author: Ganesh Badiger | Date: 2026-05-10 | Version: v3.1.0

================================================================================
SECTION 1 — EXECUTIVE SUMMARY
================================================================================

| Test Objective                              | Status      |
|---------------------------------------------|-------------|
| First login and typing sample collection    | ✅ PASS     |
| Baseline pattern created correctly          | ✅ PASS     |
| Wrong typing triggers warning + re-auth     | ✅ PASS     |
| Automated backend tests — 42 cases          | ✅ ALL PASS |
| Register page — new user signup + capture   | ✅ BUILT    |
| API typing-sample endpoint wired up         | ✅ BUILT    |

================================================================================
SECTION 2 — BUGS FOUND AND FIXED
================================================================================

BUG 1: LoginPage.jsx crashed when clicking "New user?" link
  Problem : navigate('/register') was called but useNavigate was never imported
  Fix     : Added import { useNavigate } from 'react-router-dom' and the hook
  File    : src/pages/LoginPage.jsx

BUG 2: RegisterPage.jsx used CSS class names from the wrong module
  Problem : Classes like .layout, .authPanel didn't exist in LoginPage.module.css
  Fix     : Rewrote with inline styles and full premium UI
  File    : src/pages/RegisterPage.jsx

BUG 3: logoutUser() sent token in URL not in body
  Problem : Backend expects { session_token } in POST body, not query param
  Fix     : req('/auth/logout', 'POST', { session_token: sessionToken })
  File    : src/services/api.js

BUG 4: Typing-sample heartbeat was never wired up
  Problem : /biometric/typing-sample existed but was never called from browser
  Fix     : Added sendTypingSample() in api.js + 5s heartbeat loop in AuthContext
  Files   : src/services/api.js, src/context/AuthContext.jsx

================================================================================
SECTION 3 — MANUAL TEST RESULTS
================================================================================

TEST 1 — First login and typing sample collection
-------------------------------------------------
Steps:
  1. Open http://localhost:3000
  2. Click "New user? Create an account here."
  3. Fill email + password on register page
  4. Watch keystroke ring count up with each keystroke (0 → 15)
  5. Click "CREATE ACCOUNT & CAPTURE PATTERN"
  6. App redirects to /profile-build

Result  : PASS
Evidence: ep_user and ep_token visible in DevTools → Application → Local Storage
          Register page showed live biometric capture ring incrementing to 15+
          Keystroke sparkline updated in real-time on left panel

TEST 2 — Baseline pattern created correctly
-------------------------------------------
Steps:
  1. After login, watch amber banner: "BASELINE MODE (0 / 30)"
  2. Type normally in any input field
  3. Watch counter advance: 0 → 5 → 10 → 20 → 30
  4. At 30, banner turns GREEN: "PATTERN ACTIVE"
  5. Check localStorage for ep_bioprofile_<user_id>

Result  : PASS
Evidence:
  Console: [BehavioralProfile] Updated drift: 0.198, sampleCount: 30
  Console: [AuthContext] TypingSample status=learning drift=0.20 baseline=false
  Console: [AuthContext] TypingSample status=active drift=0.18 baseline=true
  localStorage key ep_bioprofile_<id> has emaProfile array (non-null)

TEST 3 — Suspicious typing triggers warning and re-auth
-------------------------------------------------------
Steps:
  1. Confirm green baseline banner (≥30 samples)
  2. Open DevTools Console (F12), paste and run:

     const ep = window.__EP_CLIENT__
     const now = performance.now()
     for (let i = 0; i < 50; i++) {
       ep.keyboard._events.push({
         dwell: 10, flight: 5, ts: now + i * 15,
         bigramRatio: Math.random() * 2
       })
     }
     console.log('[TEST] Injected 50 rapid-typing events. Wait ~5 seconds.')

  3. Wait 5 seconds
  4. RED BANNER appears: "SUSPICIOUS TYPING DETECTED"
  5. Click "RE-AUTHENTICATE NOW"
  6. App logs out → /login shows red alert

Result  : PASS
Evidence:
  Console: [LiveEval] theta=0.089, drift=4.712, samples=31
  Console: [AuthContext] Re-auth required (typing-sample): Typing analysis:
           behavioral drift=4.71 exceeds threshold=2.5
  Backend: [TypingSample] user=abc123 ACTIVE drift=4.71 suspicious=True action=reauth
  Red banner appeared at top of page within 5 seconds
  Login page showed red "SUSPICIOUS ACTIVITY DETECTED" alert after re-auth

TEST 4 — API direct test (curl)
--------------------------------
# Learning phase:
curl -X POST http://localhost:8001/biometric/typing-sample
     -H "X-Session-Token: <token>"
     -d '{"feature_vector":[0.3,0.2,0,0,0,0.5,0,0.5],"sample_count":5,"baseline_ready":false,"drift_score":0.0}'
→ {"status":"learning","samples_collected":5,"needed":30}  ✅

# Active, normal:
     -d '{"sample_count":40,"baseline_ready":true,"drift_score":0.8,...}'
→ {"status":"active","suspicious":false,"action":"ok"}  ✅

# Active, robot typing:
     -d '{"feature_vector":[0.02,0.01,0,0,0,0.9,0,0.5],"drift_score":3.5,...}'
→ {"status":"active","suspicious":true,"action":"reauth"}  ✅

================================================================================
SECTION 4 — AUTOMATED TEST RESULTS
================================================================================

Command: venv\Scripts\python.exe -m pytest tests/test_stage1_biometric.py -v

Platform: win32 / Python 3.12.13 / pytest-9.0.3

TestBiometricInterpreterVerdicts (5/5 PASSED)
  test_clear_bot_detection             PASSED
  test_bot_boundary                    PASSED
  test_suspect_detection               PASSED
  test_human_detection                 PASSED
  test_human_boundary                  PASSED

TestConfidenceAssignment (6/6 PASSED)
  test_high_confidence_bot_clear       PASSED
  test_high_confidence_human_clear     PASSED
  test_medium_confidence_near_bot_boundary  PASSED
  test_medium_confidence_near_human_boundary  PASSED
  test_low_confidence_contested_band   PASSED
  test_low_confidence_middle_range     PASSED

TestLatentVectorHandling (6/6 PASSED)
  test_missing_latent_vector_degrades_confidence   PASSED
  test_missing_latent_vector_noted     PASSED
  test_wrong_latent_vector_size_degrades  PASSED
  test_wrong_latent_vector_size_noted  PASSED
  test_correct_latent_human_keeps_high PASSED
  test_missing_latent_human_stays_medium  PASSED

TestServerLoadAnnotation (2/2 PASSED)
  test_high_server_load_noted          PASSED
  test_normal_server_load_not_noted    PASSED

TestEdgeCases (3/3 PASSED)
  test_theta_exactly_zero              PASSED
  test_theta_exactly_one               PASSED
  test_input_data_preservation         PASSED

TestThresholdConsistency (3/3 PASSED)
  test_bot_theta_hard_constant         PASSED
  test_bot_theta_soft_constant         PASSED
  test_threshold_ordering              PASSED

--- NEW: First-User Flow Tests ---

TestBaselinePhase (4/4 PASSED)
  test_zero_latent_vector_is_low_confidence         PASSED
  test_new_user_with_random_latent_gets_medium      PASSED
  test_baseline_not_ready_still_allows_login        PASSED
  test_missing_latent_signals_baseline_not_ready    PASSED

TestSuspiciousTypingDetection (4/4 PASSED)
  test_rapid_typing_drops_into_suspect_band         PASSED
  test_borderline_rapid_typing_is_low_confidence    PASSED
  test_extreme_rapid_typing_is_bot                  PASSED
  test_suspicious_typing_without_latent_still_flagged  PASSED

TestReAuthFlow (9/9 PASSED)
  test_erec_warn_value                              PASSED
  test_erec_critical_value                          PASSED
  test_erec_ordering                                PASSED
  test_trust_warn_value                             PASSED
  test_trust_critical_value                         PASSED
  test_trust_ordering                               PASSED
  test_passive_reauth_action_exists                 PASSED
  test_force_logout_action_exists                   PASSED
  test_suspect_theta_would_trigger_reauth           PASSED

TOTAL: 42 passed, 2 warnings in 7.45s ✅

================================================================================
SECTION 5 — HOW THE FLOW WORKS (PLAIN ENGLISH SUMMARY)
================================================================================

STEP 1 — NEW USER REGISTERS
  User opens /register, fills email and password.
  The biometric engine captures their keystrokes silently as they type.
  A keystroke ring shows 0–15 captured keystrokes live.
  On submit: account created in MongoDB, session token issued, user redirected
  to /profile-build.

STEP 2 — BASELINE LEARNING (amber banner)
  The biometric client runs a live-eval loop every 1.5 seconds.
  Each loop reads keyboard events and updates the user's behavioral profile.
  The amber banner shows the count: "BASELINE MODE (0 / 30)".
  Every 5 seconds, the typing-sample heartbeat POSTs the feature vector
  to /biometric/typing-sample. Backend returns: {"status": "learning"}.
  During this phase, NO anomalies fire — prevents false alarms on new users.

STEP 3 — BASELINE READY (green banner)
  After 30 samples the profile is stable. Banner turns green:
  "PATTERN ACTIVE — suspicious changes will trigger re-auth."
  Detection is now active on every 5-second heartbeat.

STEP 4 — NORMAL SESSION
  Every 5s: typing-sample heartbeat → backend says {"action": "ok"}.
  Every 30s: watchdog heartbeat → deeper check with latent vector.
  Session continues normally.

STEP 5 — SUSPICIOUS TYPING DETECTED
  If someone types very fast, randomly, or the rhythm changes drastically:
    - drift_score > 2.5 OR dwell < 30ms
  Backend returns {"action": "reauth", "suspicious": true}.
  AuthContext sets reAuthRequired = true.
  RED BANNER appears within 5 seconds:
    "⚠ SUSPICIOUS TYPING DETECTED"
  Two buttons:
    "RE-AUTHENTICATE NOW" → logout → /login (shows red alert)
    "Dismiss" → clears banner (returns if drift continues)

================================================================================
SECTION 6 — QUICK VERIFY CHECKLIST
================================================================================

[ ] npm run dev → frontend at http://localhost:3000
[ ] Backend running at http://localhost:8001
[ ] Click "New user?" → /register opens, no crash
[ ] Register page shows live keystroke counter as you type
[ ] After register → redirected to /profile-build
[ ] Amber "BASELINE MODE" banner visible with counter
[ ] After 30 keystrokes → banner turns green
[ ] Run console snippet → red banner appears within 5 seconds
[ ] Click "RE-AUTHENTICATE NOW" → login page with red alert
[ ] pytest tests/test_stage1_biometric.py -v → 42 passed

================================================================================
Entropy Prime Team — Ganesh Badiger — 2026-05-10
================================================================================
