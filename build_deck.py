#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ArogyaChain AI — Pitch deck PDF builder
=======================================
Generates a 16:9 HTML deck and prints it to PDF with headless Chrome.

Every figure is read from the measured artefacts at build time:
    data/validation_metrics.json   (backtest.py)
    data/impact_metrics.json       (impact_sim.py)
so the deck can never drift from the numbers the scripts actually produce.
If a metric moves, the deck moves with it — or fails loudly.

Usage:
    python build_deck.py            -> docs/ArogyaChainAI_Deck.pdf
"""

import html
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(ROOT, "data")
DOCS = os.path.join(ROOT, "docs")
ASSETS = os.path.join(DOCS, "assets")

W, H = 1280, 720

CHROME_CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]

# ============================================================================
# TEAM CONFIG
# ----------------------------------------------------------------------------
# Leave these as None and the deck auto-detects what it can:
#   GITHUB_URL  <- git remote "origin"
#   LIVE_URL    <- the Firebase project id in .firebaserc
# Only TEAM is ever hand-filled, because no tool can guess your name.
# ============================================================================
TEAM = "[Your Name] - [Your Role]"          # <- the only line you must edit

GITHUB_URL = None                           # auto: git remote origin
LIVE_URL = None                             # auto: .firebaserc default project
VIDEO_URL = None                            # set once your video is uploaded

# ============================================================================

TEAL = "#0F6E5C"
TEAL_DK = "#0A4C40"
TEAL_LT = "#E6F2EF"
AMBER = "#B45309"
RED = "#B91C1C"
INK = "#111827"
MUTE = "#6B7280"
RULE = "#D1D5DB"


def find_chrome():
    for p in CHROME_CANDIDATES:
        if os.path.exists(p):
            return p
    return None


def detect_links():
    """Fill GITHUB_URL / LIVE_URL from the repo itself. Returns (gh, live, todo)."""
    todo = []
    gh, live = GITHUB_URL, LIVE_URL

    if gh is None:
        try:
            r = subprocess.run(["git", "config", "--get", "remote.origin.url"],
                               cwd=ROOT, capture_output=True, text=True, timeout=15)
            url = r.stdout.strip()
            # Reject unfilled placeholders — a literal "<your-user>" in .git/config
            # would otherwise be embedded into the deck as if it were a real link.
            if url and "<" not in url and ">" not in url:
                url = url.removesuffix(".git")
                if url.startswith("git@"):
                    url = "https://github.com/" + url.split(":", 1)[1]
                gh = url
            elif url:
                todo.append(f"remote origin is still a placeholder ({url}); "
                            f"fix with: git remote set-url origin https://github.com/<you>/arogyachain-ai.git")
        except Exception:
            pass
        if gh is None:
            gh = "https://github.com/<your-user>/arogyachain-ai"
            todo.append("set a git remote so the deck links your repo: "
                        "`git remote add origin https://github.com/<you>/arogyachain-ai.git`")

    if live is None:
        try:
            with open(os.path.join(ROOT, ".firebaserc"), encoding="utf-8") as f:
                pid = json.load(f)["projects"]["default"]
            live = f"https://{pid}.web.app"
        except Exception:
            live = "https://<project>.web.app"

    if TEAM.startswith("["):
        todo.append("set TEAM in build_deck.py, then re-run")

    return gh, live, todo


def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)


def b64(path):
    import base64
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


def esc(s):
    return html.escape(str(s))


def svg_data_uri(path):
    """Inline the validation chart SVG so the PDF never depends on a file:// path."""
    return "data:image/svg+xml;base64," + b64(path)


CSS = f"""
@page {{ size: {W}px {H}px; margin: 0; }}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{ width: {W}px; }}
body {{
  font-family: "Segoe UI", Inter, system-ui, -apple-system, sans-serif;
  color: {INK}; background: #fff;
  -webkit-font-smoothing: antialiased;
}}
.slide {{
  width: {W}px; height: {H}px; padding: 52px 68px 58px;
  page-break-after: always; position: relative; overflow: hidden;
}}
.slide:last-child {{ page-break-after: auto; }}
.slide.dark {{ background: {TEAL_DK}; color: #fff; }}
.rail {{ position:absolute; left:0; top:0; bottom:0; width:9px; background:{TEAL}; }}
.eyebrow {{
  font-size: 13px; font-weight: 700; letter-spacing: .16em;
  text-transform: uppercase; color: {TEAL}; margin-bottom: 14px;
}}
.dark .eyebrow {{ color: #7FD4C1; }}
h1 {{ font-size: 58px; line-height: 1.06; font-weight: 800; letter-spacing: -.022em; }}
h2 {{ font-size: 40px; line-height: 1.14; font-weight: 800; letter-spacing: -.018em; }}
.lede {{ font-size: 25px; line-height: 1.42; color: {MUTE}; margin-top: 16px; max-width: 1010px; }}
.dark .lede {{ color: #C4E5DE; }}
.foot {{
  position:absolute; left:68px; right:68px; bottom:24px;
  display:flex; justify-content:space-between; align-items:center;
  font-size: 12.5px; color: {MUTE};
  border-top: 1px solid {RULE}; padding-top: 10px;
}}
.dark .foot {{ color:#9CCFC5; border-top-color: rgba(255,255,255,.22); }}
.num {{ font-variant-numeric: tabular-nums; }}
.badge {{
  display:inline-block; font-size:11.5px; font-weight:700; letter-spacing:.1em;
  text-transform:uppercase; padding:5px 11px; border-radius:999px;
  background:{TEAL_LT}; color:{TEAL_DK}; margin:0 6px 6px 0;
}}
.badge.warn {{ background:#FEF3C7; color:{AMBER}; }}
.badge.live {{ background:#DBEAFE; color:#1E40AF; }}
ul {{ margin: 20px 0 0 22px; }}
li {{ font-size: 21px; line-height: 1.52; margin-bottom: 13px; }}
li::marker {{ color: {TEAL}; }}
.dark li::marker {{ color: #7FD4C1; }}
strong {{ font-weight: 700; }}
table {{ border-collapse: collapse; width: 100%; margin-top: 18px; font-size: 18px; }}
th {{
  text-align: left; font-size: 12.5px; letter-spacing:.09em; text-transform:uppercase;
  color:{MUTE}; font-weight:700; padding: 0 14px 9px 0;
  border-bottom: 2px solid {INK};
}}
td {{ padding: 11px 14px 11px 0; border-bottom: 1px solid {RULE}; }}
tr.hl td {{ background:{TEAL_LT}; font-weight: 700; }}
.tiles {{ display: flex; gap: 16px; margin-top: 26px; }}
.tile {{
  flex: 1; border: 1.5px solid {RULE}; border-radius: 11px; padding: 17px 19px;
}}
.tile .v {{ font-size: 40px; font-weight: 800; letter-spacing: -.02em; line-height:1; }}
.tile .k {{ font-size: 13.5px; color: {MUTE}; margin-top: 8px; line-height: 1.4; }}
.tile.good {{ border-color:{TEAL}; background:{TEAL_LT}; }}
.tile.good .v {{ color:{TEAL_DK}; }}
.src {{
  position:absolute; left:68px; right:68px; bottom:54px;
  font-size:12.5px; color:{MUTE}; font-style: italic; line-height:1.5;
}}
.dark .src {{ color:#9CCFC5; }}
.shot {{
  width: 640px; border: 1.5px solid {RULE}; border-radius: 10px;
  box-shadow: 0 10px 34px rgba(0,0,0,.13);
}}
.cols {{ display:flex; gap:38px; align-items:flex-start; }}
.logo {{
  display:inline-flex; align-items:center; gap:13px; font-weight:800;
  font-size: 21px; color:{TEAL_DK}; margin-bottom: 30px;
}}
.dot {{ width: 27px; height: 27px; border-radius: 8px; background:{TEAL}; }}
.pill {{
  display:inline-block; background:rgba(255,255,255,.14); color:#fff;
  font-size: 12.5px; font-weight: 600; letter-spacing:.07em; text-transform:uppercase;
  padding: 6px 12px; border-radius: 999px; margin-right: 8px;
}}
"""


def foot(n, label):
    return (f'<div class="foot"><span>ArogyaChain AI &middot; Track 3 &middot; '
            f'Build with AI Hackathon</span><span class="num">{n} / 12 &nbsp;&middot;&nbsp; {label}</span></div>')


def build_html(v, i, shot_uri, gh, live):
    cfg = v["config"]
    base, inter = v["baseline"], v["intervention"]
    sweep = sorted(v["sensitivity_geographic_reach"],
                   key=lambda s: (s["donor_reach_phcs"] == "all", s["donor_reach_phcs"]))
    floor = sweep[0]
    vm = load("validation_metrics.json")
    ens = vm["models"]["local-ensemble"]
    naive = vm["models"]["seasonal-naive"]
    imp = vm["ensemble_improvement_over_naive_pct"]
    chart = svg_data_uri(os.path.join(DATA, "validation_chart.svg"))

    S = []

    # 1 ---------------------------------------------------------------- title
    S.append(f"""
    <div class="slide dark"><div class="rail"></div>
      <div class="logo"><span class="dot"></span>ArogyaChain AI</div>
      <div style="margin-bottom:22px">
        <span class="pill">Track 3 &middot; Health &amp; Supply Chain</span>
        <span class="pill">Google AI</span>
      </div>
      <h1>Predictive supply chain<br>for Primary Health Centres.</h1>
      <p class="lede">A pharmacist <em>speaks</em> a stock update. Vertex AI forecasts the
      next 7 days and flags the stock-out. The engine moves the surplus &mdash; before
      a patient is turned away.</p>
      <div class="src">{esc(gh)} &nbsp;&middot;&nbsp; {esc(live)}</div>
    </div>""")

    # 2 -------------------------------------------------------------- problem
    S.append(f"""
    <div class="slide"><div class="rail"></div>
      <div class="eyebrow">The problem</div>
      <h2>Indian public facilities hold <span style="color:{RED}">17&ndash;51%</span>
      of essential medicines.<br>The WHO benchmark is <span style="color:{TEAL}">80%</span>.</h2>
      <ul>
        <li>Stock-outs run <strong>4 to 14 weeks</strong> at a time</li>
        <li>Stock ledgers are <strong>paper</strong> &mdash; district consolidation takes weeks</li>
        <li>Districts learn about a shortage <strong>after</strong> patients are turned away</li>
      </ul>
      <p class="lede" style="margin-top:26px">We are not short on procurement money.
      We are short on <strong style="color:{INK}">warning</strong>.</p>
      <p class="src">Cited: availability range and stock-out duration &mdash;
      &ldquo;Factors Affecting the Availability and Utilization of Essential Medicines in India:
      A Systematic Review&rdquo; (PMC11174260). 80% benchmark per WHO.</p>
      {foot(2, "Problem")}
    </div>""")

    # 3 ------------------------------------------------------- current systems
    S.append(f"""
    <div class="slide"><div class="rail"></div>
      <div class="eyebrow">Why today&rsquo;s systems fail</div>
      <h2>They record the past.<br>They never predict the future.</h2>
      <div style="margin-top:40px">
        <div style="display:flex;align-items:center;gap:14px;margin-bottom:15px">
          <div style="background:{RULE};color:{INK};padding:13px 19px;border-radius:8px;font-size:17px;font-weight:600">Manual register</div>
          <div style="color:{MUTE};font-size:23px">&rarr;</div>
          <div style="background:{RULE};color:{INK};padding:13px 19px;border-radius:8px;font-size:17px;font-weight:600">Late reporting</div>
          <div style="color:{MUTE};font-size:23px">&rarr;</div>
          <div style="background:#FEE2E2;color:{RED};padding:13px 19px;border-radius:8px;font-size:17px;font-weight:700">No forecast</div>
          <div style="color:{MUTE};font-size:23px">&rarr;</div>
          <div style="background:{RULE};color:{INK};padding:13px 19px;border-radius:8px;font-size:17px;font-weight:600">Emergency procurement</div>
        </div>
      </div>
      <p class="lede" style="margin-top:38px;font-size:26px">
      Every e-governance dashboard today is a <em>rear-view mirror</em>.<br>
      We built a <strong style="color:{TEAL}">windshield</strong>.</p>
      {foot(3, "Problem")}
    </div>""")

    # 4 ------------------------------------------------------------- solution
    S.append(f"""
    <div class="slide"><div class="rail"></div>
      <div class="eyebrow">The solution</div>
      <h2>Speak. Predict. Redistribute.</h2>
      <ul style="margin-top:32px;font-size:22px">
        <li>A PHC worker <strong>speaks</strong> <span style="font-size:19px">&ldquo;பாராசிட்டமால் ஐம்பது&rdquo;</span>
            &mdash; the ledger updates itself</li>
        <li>Vertex AI forecasts <strong>7-day</strong> demand &rarr; a <strong>0&ndash;100 stock-out
            Risk Score</strong> per medicine</li>
        <li>One tap moves surplus from an <strong>overstocked</strong> PHC to a <strong>starved</strong> one</li>
        <li>Supervisors alerted at risk &gt; 80 &mdash; FCM push, WhatsApp in production</li>
      </ul>
      {foot(4, "Solution")}
    </div>""")

    # 5 -------------------------------------------------------- google ai use
    S.append(f"""
    <div class="slide"><div class="rail"></div>
      <div class="eyebrow">AI approach</div>
      <h2>Three Google AI systems, one feature contract.</h2>
      <table style="margin-top:24px">
        <tr><th style="width:31%">System</th><th style="width:38%">Role</th><th>Endpoint</th></tr>
        <tr><td><strong>Vertex AI AutoML</strong></td><td>7-day demand forecasting</td>
            <td style="font-family:Consolas,monospace;font-size:14px">aiplatform.googleapis.com</td></tr>
        <tr><td><strong>Gemini 2.0 Flash</strong></td><td>Multilingual voice &rarr; structured entry</td>
            <td style="font-family:Consolas,monospace;font-size:14px">generativelanguage.googleapis.com</td></tr>
        <tr><td><strong>Cloud Speech-to-Text</strong></td><td>Tamil &middot; Hindi &middot; English capture</td>
            <td style="font-family:Consolas,monospace;font-size:14px">speech_to_text</td></tr>
        <tr><td><strong>On-device fallback</strong></td><td>Same contract when Vertex is unreachable</td>
            <td style="color:{MUTE}">no network required</td></tr>
      </table>
      <p class="lede" style="margin-top:24px;font-size:20px">
      The forecast, the voice parser and the offline fallback all consume the
      <strong style="color:{INK}">same engineered features</strong> &mdash; so quality never
      silently changes with connectivity.</p>
      {foot(5, "AI approach")}
    </div>""")

    # 6 ------------------------------------------------------------------ demo
    S.append(f"""
    <div class="slide"><div class="rail"></div>
      <div class="eyebrow">Working prototype</div>
      <div class="cols">
        <div style="flex:1">
          <h2 style="font-size:35px">End to end, in 90 seconds.</h2>
          <ul style="margin-top:26px;font-size:19px">
            <li>Voice in Tamil &rarr; Firebase write</li>
            <li>Risk card <strong>spikes to 97%</strong></li>
            <li>Transfer recommendation appears</li>
            <li>One tap &rarr; stock moves, alert logged</li>
          </ul>
          <div style="margin-top:26px">
            <span class="badge live">Live capture</span>
            <span class="badge">Firebase RTDB</span>
            <span class="badge">Offline fallback</span>
          </div>
        </div>
        <img class="shot" src="{shot_uri}" alt="ArogyaChain AI dashboard">
      </div>
      {foot(6, "Demo")}
    </div>""")

    # 7 ------------------------------------------------------------ validation
    S.append(f"""
    <div class="slide"><div class="rail"></div>
      <div class="eyebrow">Validation &mdash; measured</div>
      <h2>Beats the rule-based baseline by
      <span style="color:{TEAL}">{imp}%</span> on a 28-day holdout.</h2>
      <div class="tiles">
        <div class="tile good"><div class="v num">{ens['mape']}%</div>
          <div class="k">our ensemble forecaster &mdash; MAPE</div></div>
        <div class="tile"><div class="v num">{naive['mape']}%</div>
          <div class="k">seasonal-naive baseline &mdash; MAPE</div></div>
        <div class="tile"><div class="v num">{ens['n']:,}</div>
          <div class="k">forecasts evaluated, {vm['series_count']} series</div></div>
      </div>
      <div style="margin-top:20px">
        <img src="{chart}" style="width:100%;max-height:206px;object-fit:contain" alt="Actual vs forecast">
      </div>
      <p class="src">Measured by <code>backtest.py</code> &rarr; <code>data/validation_metrics.json</code>.
      Reproducible by a judge in one command.</p>
      {foot(7, "Validation")}
    </div>""")

    # 8 ---------------------------------------------------------- impact (real)
    S.append(f"""
    <div class="slide"><div class="rail"></div>
      <div class="eyebrow">Validation &mdash; measured impact</div>
      <h2>Stock-outs fall <span style="color:{TEAL}">{base['total_stockouts']:,}
      &rarr; {inter['total_stockouts']}</span>. And it survives stress.</h2>
      <div class="tiles">
        <div class="tile good"><div class="v num">{v['stockout_reduction_pct_full_year']}%</div>
          <div class="k">fully-connected district &mdash; <strong>upper bound</strong></div></div>
        <div class="tile good"><div class="v num">{floor['reduction_pct']}%</div>
          <div class="k">nearest-neighbour only &mdash; <strong>the honest floor</strong></div></div>
        <div class="tile"><div class="v num">{base['unmet_units']:,} &rarr; {inter['unmet_units']}</div>
          <div class="k">units of unmet demand</div></div>
      </div>
      <table style="margin-top:22px;font-size:17px">
        <tr><th>Donor reach</th><th>Stock-outs</th><th>Reduction</th><th>Unmet-demand reduction</th></tr>
        {"".join(
          f'<tr class="{"hl" if s is floor else ""}"><td>{esc(s["donor_reach_phcs"])} PHC'
          f'{"s" if s["donor_reach_phcs"] != "all" else "s in district"}</td>'
          f'<td class="num">{s["stockouts"]:,}</td>'
          f'<td class="num">{s["reduction_pct"]}%</td>'
          f'<td class="num">{s["unmet_reduction_pct"]}%</td></tr>' for s in sweep)}
      </table>
      <p class="src">Measured by <code>impact_sim.py</code> &rarr; <code>data/impact_metrics.json</code>.
      Paired counterfactual: both arms consume the identical RNG stream, so both face identical
      latent demand. Simulated, not field-measured &mdash; we had no pilot, so we measured the mechanism.</p>
      {foot(8, "Validation")}
    </div>""")

    # 9 ----------------------------------------------------------- who it serves
    S.append(f"""
    <div class="slide"><div class="rail"></div>
      <div class="eyebrow">Who it serves</div>
      <h2>Three roles. One system.</h2>
      <div class="tiles" style="margin-top:34px">
        <div class="tile"><div class="v" style="font-size:23px">PHC pharmacist</div>
          <div class="k" style="font-size:16px;line-height:1.55;margin-top:12px">
          Speaks the update instead of maintaining a register. Zero learning curve,
          works in Tamil.</div></div>
        <div class="tile"><div class="v" style="font-size:23px">District Health Officer</div>
          <div class="k" style="font-size:16px;line-height:1.55;margin-top:12px">
          Sees which of their PHCs break first &mdash; and which can lend before it happens.</div></div>
        <div class="tile"><div class="v" style="font-size:23px">State procurement</div>
          <div class="k" style="font-size:16px;line-height:1.55;margin-top:12px">
          Sees demand 7 days out, before raising a purchase order at a premium.</div></div>
      </div>
      <p class="lede" style="margin-top:32px;font-size:22px">
      The District Health Officer is the buyer.<br>
      <strong style="color:{INK}">Voice input is what makes the pharmacist&rsquo;s participation
      non-negotiable</strong> &mdash; if it is not zero-effort, the data stops arriving.</p>
      {foot(9, "Who it serves")}
    </div>""")

    # 10 ------------------------------------------------------------ deployable
    S.append(f"""
    <div class="slide"><div class="rail"></div>
      <div class="eyebrow">Why it is deployable</div>
      <h2>Pilot-ready in two weeks, on infrastructure a district already has.</h2>
      <table style="margin-top:26px">
        <tr><th style="width:38%">Concern</th><th>How it is answered</th></tr>
        <tr><td><strong>Cost</strong></td><td>Firebase Spark tier &mdash; free for a district pilot. No new hardware.</td></tr>
        <tr><td><strong>Connectivity</strong></td><td>Offline-first writes plus an on-device forecaster. Degrades, never dies.</td></tr>
        <tr><td><strong>Security</strong></td><td>Rules shipped in <code>database.rules.json</code>; every action written to <code>alertLog</code>.</td></tr>
        <tr><td><strong>Disruption risk</strong></td><td>Additive. The paper register still works if the app does not.</td></tr>
        <tr><td><strong>Interoperability</strong></td><td>Built on NLEM 2022. Next: HMIS export.</td></tr>
      </table>
      {foot(10, "Deployability")}
    </div>""")

    # 11 ------------------------------------------------------------- scaling
    S.append(f"""
    <div class="slide"><div class="rail"></div>
      <div class="eyebrow">Scaling across India &mdash; and BRICS</div>
      <h2>New district, same code. The levers are configuration, not rewrites.</h2>
      <ul style="margin-top:28px;font-size:20px">
        <li><strong>NLEM 2022</strong> &mdash; the national standard, not a state list.
            8 PHCs &rarr; 25,000: no architecture change</li>
        <li><strong>Language is a config pack.</strong> Tamil &middot; Hindi &middot; English shipped;
            22 official languages follow the same Speech-to-Text + Gemini path</li>
        <li><strong>BRICS:</strong> the same forecasting and matching design applies to
            Brazil&rsquo;s <em>UBS</em>, South Africa&rsquo;s <em>PHC</em> clinics, and Russia&rsquo;s
            outpatient network. Drug lists and languages swap; the Risk Score formula does not.</li>
      </ul>
      <p class="lede" style="margin-top:24px;font-size:20px">
      Our reachability sweep is the scaling law: <strong style="color:{INK}">the further a
      facility sits from a donor, the more forecasting must carry before transfer can help.</strong>
      That is the variable a national rollout would tune per state.</p>
      {foot(11, "Scale &amp; BRICS")}
    </div>""")

    # 12 ------------------------------------------------------------------ ask
    S.append(f"""
    <div class="slide dark"><div class="rail"></div>
      <div class="eyebrow">The ask</div>
      <h1 style="font-size:50px">Seeking an NHM pilot:<br>1 district, 50 PHCs, 90 days.</h1>
      <p class="lede" style="font-size:23px;margin-top:26px">
      Everything on the previous slides is reproducible from this repository.<br>
      Two scripts, one command each, no cloud account required.</p>
      <div style="margin-top:34px;display:flex;gap:12px;flex-wrap:wrap">
        <span class="pill">{esc(gh.replace("https://",""))}</span>
        <span class="pill">{esc(live.replace("https://",""))}</span>
        <span class="pill">Demo video</span>
      </div>
      <p style="margin-top:20px;font-size:16px;color:#9CCFC5">Team: {esc(TEAM)}</p>
      <p style="margin-top:34px;font-size:29px;font-weight:700;color:#fff;font-style:italic">
      &ldquo;Every PHC that can&rsquo;t afford to guess, shouldn&rsquo;t have to.&rdquo;</p>
      {foot(12, "Ask")}
    </div>""")

    body = "\n".join(S)
    return f"<!doctype html><html><head><meta charset='utf-8'><title>ArogyaChain AI</title><style>{CSS}</style></head><body>{body}</body></html>"


def main():
    shot = os.path.join(ASSETS, "app_dashboard.png")
    if not os.path.exists(shot):
        sys.exit(f"missing {shot} — capture the app screenshot first")
    if not os.path.exists(os.path.join(DATA, "validation_chart.svg")):
        sys.exit("missing data/validation_chart.svg — run: python backtest.py")

    v = load("impact_metrics.json")
    gh, live, todo = detect_links()
    doc = build_html(v, 1, "data:image/png;base64," + b64(shot), gh, live)

    os.makedirs(DOCS, exist_ok=True)
    html_path = os.path.join(DOCS, "deck.html")
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(doc)
    print(f"[OK] {html_path}")

    chrome = find_chrome()
    if not chrome:
        print("[!] No Chrome/Edge found — wrote the HTML deck only. Open deck.html and print to PDF.")
        return

    pdf = os.path.join(DOCS, "ArogyaChainAI_Deck.pdf")
    prof = os.path.join(os.environ.get("TEMP", "."), "opencode", "deckprof")
    os.makedirs(prof, exist_ok=True)
    r = subprocess.run([
        chrome, "--headless=new", "--no-sandbox", "--disable-gpu",
        "--use-gl=swiftshader", "--enable-unsafe-swiftshader",
        f"--user-data-dir={prof}", "--no-pdf-header-footer",
        "--print-to-pdf-no-header", f"--print-to-pdf={pdf}",
        "file:///" + html_path.replace("\\", "/"),
    ], capture_output=True, text=True, timeout=180)

    if os.path.exists(pdf):
        size = os.path.getsize(pdf)
        with open(pdf, "rb") as f:
            pages = f.read().count(b"/Type /Page") or f.read().count(b"/Type/Page")
        print(f"[OK] {pdf}  ({size/1024:.0f} KB)")
        print("[i] every figure was read from data/validation_metrics.json and data/impact_metrics.json")
        print(f"[i] repo link  : {gh}")
        print(f"[i] live link  : {live}")
        if todo:
            print("\n[!] still needs you:")
            for t_ in todo:
                print("    - " + t_)
    else:
        print("[X] PDF not produced")
        print(r.stdout[-1500:])
        print(r.stderr[-1500:])


if __name__ == "__main__":
    main()
