# e:\Society_Managment\master_run.py
# ─────────────────────────────────────────────────────────────────
# Society Manager — Master Agent Runner v7.0
# Reads master_agent_prompt_v3.md and executes it phase by phase.
# Scans existing files, skips done work, resumes pending.
# ─────────────────────────────────────────────────────────────────
import pathlib, sys, os, re, json, time, threading, urllib.request, urllib.error
import argparse
import shutil
from datetime import datetime

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# ── Paths ────────────────────────────────────────────────────────
BASE_DIR     = pathlib.Path("e:/Society_Managment")
BACKEND_DIR  = BASE_DIR / "backend"
FRONTEND_DIR = BASE_DIR / "frontend"
PROMPT_FILE  = BASE_DIR / "master_agent_prompt_v3.md"
SESSION_LOG  = BASE_DIR / "session.log"
CONTEXT_FILE = BASE_DIR / ".agents" / "pipeline_context.md"

MODEL      = "gemma3:12b"
OLLAMA_URL = "http://localhost:11434/api/generate"

# ── What "done" means for each feature ───────────────────────────
def _be(p): return (BACKEND_DIR  / p).exists()
def _fe(p): return (FRONTEND_DIR / p).exists()

FEATURES = {
    # BACKEND
    "BE: Prisma schema":          lambda: _be("prisma/schema.prisma"),
    "BE: Express app entry":      lambda: _be("src/app.js"),
    "BE: Auth module":            lambda: _be("src/modules/auth/auth.routes.js"),
    "BE: Members module":         lambda: _be("src/modules/members/members.routes.js"),
    "BE: Bills module":           lambda: _be("src/modules/bills/bills.routes.js"),
    "BE: Expenses module":        lambda: _be("src/modules/expenses/expenses.routes.js"),
    "BE: Complaints module":      lambda: _be("src/modules/complaints/complaints.routes.js"),
    "BE: Visitors module":        lambda: _be("src/modules/visitors/visitors.routes.js"),
    "BE: Notices module":         lambda: _be("src/modules/notices/notices.routes.js"),
    "BE: Amenities module":       lambda: _be("src/modules/amenities/amenities.routes.js"),
    "BE: Notifications module":   lambda: _be("src/modules/notifications/notifications.routes.js"),
    "BE: Staff/Attendance module":lambda: _be("src/modules/staff/staff.routes.js"),
    "BE: Gate Pass module":       lambda: _be("src/modules/gatepasses/gatepasses.routes.js"),
    "BE: Domestic Help module":   lambda: _be("src/modules/domestichelp/domestichelp.routes.js"),
    "BE: Delivery module":        lambda: _be("src/modules/deliveries/deliveries.routes.js"),
    "BE: Vehicles module":        lambda: _be("src/modules/vehicles/vehicles.routes.js"),
    "BE: Move Requests module":   lambda: _be("src/modules/moverequests/moverequests.routes.js"),
    "BE: Dashboard module":       lambda: _be("src/modules/dashboard/dashboard.routes.js"),
    "BE: Plans/Subscriptions":    lambda: _be("src/modules/plans/plans.routes.js"),
    "BE: .env.example":           lambda: _be(".env.example"),
    "BE: Jest tests":             lambda: _be("src/modules/auth/auth.test.js") or _be("tests/auth.test.js"),
    # FLUTTER FRONTEND
    "FE: main.dart + router":     lambda: _fe("lib/main.dart") and _fe("lib/core/router/app_router.dart"),
    "FE: Theme (AppColors)":      lambda: _fe("lib/core/theme/app_colors.dart"),
    "FE: API client (Dio)":       lambda: _fe("lib/core/api/dio_client.dart"),
    "FE: Auth screens":           lambda: _fe("lib/features/auth/screens/login_screen.dart") and _fe("lib/features/auth/screens/register_screen.dart"),
    "FE: Auth provider":          lambda: _fe("lib/core/providers/auth_provider.dart"),
    "FE: Dashboard screen":       lambda: _fe("lib/features/dashboard/screens/dashboard_screen.dart"),
    "FE: Members screen":         lambda: _fe("lib/features/members/screens/members_screen.dart"),
    "FE: Bills screen":           lambda: _fe("lib/features/bills/screens/bills_screen.dart"),
    "FE: Expenses screen":        lambda: _fe("lib/features/expenses/screens/expenses_screen.dart"),
    "FE: Complaints screen":      lambda: _fe("lib/features/complaints/screens/complaints_screen.dart"),
    "FE: Visitors screen":        lambda: _fe("lib/features/visitors/screens/visitors_screen.dart"),
    "FE: Notices screen":         lambda: _fe("lib/features/notices/screens/notices_screen.dart"),
    "FE: Amenities screen":       lambda: _fe("lib/features/amenities/screens/amenities_screen.dart"),
    "FE: Notifications screen":   lambda: _fe("lib/features/notifications/screens/notifications_screen.dart"),
    "FE: Staff screen":           lambda: _fe("lib/features/staff/screens/staff_screen.dart"),
    "FE: Gate Pass screen":       lambda: _fe("lib/features/gatepasses/screens/gate_pass_screen.dart"),
    "FE: Domestic Help screen":   lambda: _fe("lib/features/domestichelp/screens/domestic_help_screen.dart"),
    "FE: Delivery screen":        lambda: _fe("lib/features/deliveries/screens/delivery_screen.dart"),
    "FE: Vehicles screen":        lambda: _fe("lib/features/vehicles/screens/vehicles_screen.dart"),
    "FE: SuperAdmin dashboard":   lambda: _fe("lib/features/superadmin/screens/sa_dashboard_screen.dart"),
    "FE: Widget tests":           lambda: _fe("test/widget_test.dart"),
}

# ── Utilities ─────────────────────────────────────────────────────

def log(msg):
    ts = datetime.now().strftime("[%H:%M:%S]")
    with SESSION_LOG.open("a", encoding="utf-8") as f:
        f.write(f"{ts} {msg}\n")

def status_snapshot():
    return {k: fn() for k, fn in FEATURES.items()}

def pending_list():
    return [k for k, fn in FEATURES.items() if not fn()]

def done_list():
    return [k for k, fn in FEATURES.items() if fn()]

def print_dashboard(agent="", step=0, total=0):
    os.system('cls' if os.name == 'nt' else 'clear')
    snap = status_snapshot()
    done_count = sum(snap.values())
    total_count = len(snap)
    be = [(k, v) for k, v in snap.items() if k.startswith("BE:")]
    fe = [(k, v) for k, v in snap.items() if k.startswith("FE:")]

    print("=" * 72)
    print("   SOCIETY MANAGER  ─  FULL-STACK AI PIPELINE")
    print("=" * 72)
    if agent:
        filled = int((step / total) * 32)
        bar = "#" * filled + "-" * (32 - filled)
        print(f"   Agent    : [{bar}] {step}/{total}")
        print(f"   Running  : {agent}")
    print(f"   Features : {done_count}/{total_count} done  ({total_count - done_count} pending)")
    print(f"   Time     : {datetime.now().strftime('%H:%M:%S')}")
    print("─" * 72)

    W = 36
    print(f"   {'BACKEND':<{W}} FLUTTER FRONTEND")
    print(f"   {'─'*W} {'─'*W}")
    for i in range(max(len(be), len(fe))):
        bl = be[i] if i < len(be) else ("", None)
        fl = fe[i] if i < len(fe) else ("", None)
        bs = ("[+]" if bl[1] else "[ ]") + " " + bl[0][4:] if bl[0] else ""
        fs = ("[+]" if fl[1] else "[ ]") + " " + fl[0][4:] if fl[0] else ""
        print(f"   {bs:<{W}} {fs}")

    print("=" * 72)
    if agent:
        print("   LIVE OUTPUT  (token by token from local model):")
        print("─" * 72)

def save_context(label, text):
    CONTEXT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with CONTEXT_FILE.open("a", encoding="utf-8") as f:
        f.write(f"\n\n---\n## {label}\n---\n{text}")

def load_context():
    return CONTEXT_FILE.read_text(encoding="utf-8") if CONTEXT_FILE.exists() else ""

def write_files(text, root=BASE_DIR):
    """
    Parse model output and write files to disk.
    Handles multiple patterns the model might use:
      1. // FILE: path\\n```lang\\n...\\n```
      2. ### File: path\\n```lang\\n...\\n```
      3. **File: path**\\n```lang\\n...\\n```
      4. === path ===\\n```lang\\n...\\n```
    """
    patterns = [
        # Primary: // FILE: path
        re.compile(r'^// FILE: ([^\n]+)\n```[^\n]*\n(.*?)^```', re.MULTILINE | re.DOTALL),
        # Alternate: # FILE: path  or  ## File: path
        re.compile(r'^#+\s*[Ff]ile:\s*([^\n]+)\n```[^\n]*\n(.*?)^```', re.MULTILINE | re.DOTALL),
        # Alternate: **File: path**
        re.compile(r'^\*\*[Ff]ile:\s*([^*\n]+)\*\*\n```[^\n]*\n(.*?)^```', re.MULTILINE | re.DOTALL),
        # Alternate: === path ===
        re.compile(r'^={3}\s*([^\n=]+?)\s*={3}\n```[^\n]*\n(.*?)^```', re.MULTILINE | re.DOTALL),
    ]

    seen = set()
    written = []

    for pat in patterns:
        for rel, content in pat.findall(text):
            rel = rel.strip().strip('`').strip('"').strip("'")
            # Only accept paths starting with backend/ or frontend/
            if not (rel.startswith("backend/") or rel.startswith("frontend/")):
                continue
            if rel in seen:
                continue
            seen.add(rel)
            target = root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
            written.append(rel)
            log(f"  [WROTE] {rel}")

    if not written:
        log("  [WARN] No files parsed from model output — model may not have used FILE: format")

    return written

# ── Ollama HTTP streaming ─────────────────────────────────────────

def ask_model(prompt):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "stream": True}).encode()
    req = urllib.request.Request(OLLAMA_URL, data=payload,
                                 headers={"Content-Type": "application/json"}, method="POST")
    chunks = []
    first = True
    stop = threading.Event()

    def spin():
        f = ["|", "/", "-", "\\"]
        i = 0
        while not stop.is_set():
            sys.stdout.write(f"\r   Waiting for model... {f[i%4]}  ")
            sys.stdout.flush()
            time.sleep(0.15); i += 1

    t = threading.Thread(target=spin, daemon=True)
    t.start()

    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            for raw in resp:
                try: obj = json.loads(raw.decode("utf-8").strip())
                except: continue
                tok = obj.get("response", "")
                if tok:
                    if first:
                        stop.set(); t.join()
                        sys.stdout.write("\r" + " " * 50 + "\r")
                        sys.stdout.flush()
                        first = False
                    try: sys.stdout.write(tok); sys.stdout.flush()
                    except UnicodeEncodeError:
                        sys.stdout.write(tok.encode("ascii","replace").decode()); sys.stdout.flush()
                    chunks.append(tok)
                if obj.get("done"):
                    print(); break
    except urllib.error.URLError as e:
        stop.set()
        print(f"\n[FATAL] Ollama unreachable: {e}\nRun: ollama serve")
        sys.exit(1)

    return "".join(chunks)

# ── FILE FORMAT instruction (appended to every prompt) ────────────

FILE_FMT = """
=== MANDATORY OUTPUT FORMAT — READ THIS CAREFULLY ===

You MUST output every file using this EXACT format.
The system will auto-parse your output and write files to disk.
If you do not use this format, NO files will be saved.

FORMAT:
// FILE: backend/src/modules/members/members.routes.js
```js
<complete file content — never truncate>
```

// FILE: frontend/lib/features/members/screens/members_screen.dart
```dart
<complete file content — never truncate>
```

RULES:
- "// FILE:" must be at the START of the line, no spaces before it.
- Path starts with "backend/" for Node.js or "frontend/" for Flutter/Dart.
- The code block must open with ``` immediately after the FILE line.
- NEVER write "// ... rest of file" or truncate content. Always write the FULL file.
- Output EVERY pending file listed above. Do not skip any.
=== END FORMAT ===
"""

# ── Phase runners ─────────────────────────────────────────────────

def clean_output(text: str) -> str:
    """Remove ANSI escape codes, spinner chars, carriage returns."""
    text = re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', text)   # ANSI codes
    text = re.sub(r'\x1b[()][AB012]', '', text)            # charset codes
    text = re.sub(r'[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]\s*', '', text)        # spinner chars
    text = re.sub(r'\r', '', text)                         # carriage returns
    text = re.sub(r'\n{3,}', '\n\n', text)                 # collapse blank lines
    return text.strip()

def run_phase(label, prompt, step, total):
    print_dashboard(label, step, total)
    log(f"START: {label}")
    out = ask_model(prompt)
    out = clean_output(out)
    save_context(label, out)
    safe = label.lower().replace(" ", "_").replace("/", "_").replace(":", "")
    out_file = BASE_DIR / f"output_{safe}.txt"
    out_file.write_text(
        f"# {label}\n"
        f"# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        f"{'=' * 60}\n\n"
        f"{out}\n",
        encoding="utf-8"
    )
    write_files(out, BASE_DIR)
    log(f"DONE:  {label}")
    return out


def build_phases(master_prompt):
    """
    Build the list of phases to run based on what is PENDING.
    Each phase targets a specific section of master_agent_prompt_v3.md.
    """
    pend = pending_list()
    done = done_list()
    ctx  = load_context()

    be_pending = [p for p in pend if p.startswith("BE:")]
    fe_pending = [p for p in pend if p.startswith("FE:")]

    phases = []

    # ── PHASE 1: Backend ─────────────────────────────────────────
    # Map feature label → exact files expected
    BE_FILE_MAP = {
        "BE: Members module":          ["backend/src/modules/members/members.routes.js","backend/src/modules/members/members.controller.js","backend/src/modules/members/members.service.js"],
        "BE: Amenities module":        ["backend/src/modules/amenities/amenities.routes.js","backend/src/modules/amenities/amenities.controller.js","backend/src/modules/amenities/amenities.service.js"],
        "BE: Staff/Attendance module": ["backend/src/modules/staff/staff.routes.js","backend/src/modules/staff/staff.controller.js","backend/src/modules/staff/staff.service.js"],
        "BE: Gate Pass module":        ["backend/src/modules/gatepasses/gatepasses.routes.js","backend/src/modules/gatepasses/gatepasses.controller.js","backend/src/modules/gatepasses/gatepasses.service.js"],
        "BE: Domestic Help module":    ["backend/src/modules/domestichelp/domestichelp.routes.js","backend/src/modules/domestichelp/domestichelp.controller.js","backend/src/modules/domestichelp/domestichelp.service.js"],
        "BE: Delivery module":         ["backend/src/modules/deliveries/deliveries.routes.js","backend/src/modules/deliveries/deliveries.controller.js","backend/src/modules/deliveries/deliveries.service.js"],
        "BE: Vehicles module":         ["backend/src/modules/vehicles/vehicles.routes.js","backend/src/modules/vehicles/vehicles.controller.js","backend/src/modules/vehicles/vehicles.service.js"],
        "BE: Move Requests module":    ["backend/src/modules/moverequests/moverequests.routes.js","backend/src/modules/moverequests/moverequests.controller.js","backend/src/modules/moverequests/moverequests.service.js"],
        "BE: Complaints module":       ["backend/src/modules/complaints/complaints.routes.js","backend/src/modules/complaints/complaints.controller.js","backend/src/modules/complaints/complaints.service.js"],
        "BE: Notices module":          ["backend/src/modules/notices/notices.routes.js","backend/src/modules/notices/notices.controller.js","backend/src/modules/notices/notices.service.js"],
        "BE: Jest tests":              ["backend/src/modules/auth/auth.test.js"],
    }
    FE_FILE_MAP = {
        "FE: main.dart + router":      ["frontend/lib/main.dart","frontend/lib/core/router/app_router.dart"],
        "FE: Theme (AppColors)":       ["frontend/lib/core/theme/app_colors.dart","frontend/lib/core/theme/app_text_styles.dart"],
        "FE: Auth screens":            ["frontend/lib/features/auth/screens/login_screen.dart","frontend/lib/features/auth/screens/register_screen.dart"],
        "FE: Gate Pass screen":        ["frontend/lib/features/gatepasses/screens/gate_pass_screen.dart","frontend/lib/features/gatepasses/providers/gate_pass_provider.dart"],
        "FE: Domestic Help screen":    ["frontend/lib/features/domestichelp/screens/domestic_help_screen.dart","frontend/lib/features/domestichelp/providers/domestic_help_provider.dart"],
        "FE: Delivery screen":         ["frontend/lib/features/deliveries/screens/delivery_screen.dart","frontend/lib/features/deliveries/providers/delivery_provider.dart"],
        "FE: Members screen":          ["frontend/lib/features/members/screens/members_screen.dart","frontend/lib/features/members/providers/members_provider.dart"],
        "FE: Notices screen":          ["frontend/lib/features/notices/screens/notices_screen.dart","frontend/lib/features/notices/providers/notices_provider.dart"],
        "FE: Amenities screen":        ["frontend/lib/features/amenities/screens/amenities_screen.dart","frontend/lib/features/amenities/providers/amenities_provider.dart"],
        "FE: Notifications screen":    ["frontend/lib/features/notifications/screens/notifications_screen.dart","frontend/lib/features/notifications/providers/notifications_provider.dart"],
        "FE: Widget tests":            ["frontend/test/widget_test.dart"],
    }
    # If rebuild features requested, delete their generated files to force regeneration
    if REBUILD_FEATURES:
        for label in REBUILD_FEATURES:
            files = BE_FILE_MAP.get(label, []) + FE_FILE_MAP.get(label, [])
            for rel in files:
                path = BASE_DIR / rel
                if path.exists():
                    path.unlink()
                    log(f"[REBUILD] Deleted {rel}")
    
    if be_pending:
        # Build explicit file list so model knows exact paths to output
        be_files_needed = []
        for p in be_pending:
            be_files_needed.extend(BE_FILE_MAP.get(p, []))

        phases.append((
            "Backend Developer",
            f"""You are an autonomous full-stack engineer executing the Society Manager project.

{master_prompt}

─── ALREADY BUILT (do NOT rewrite these) ────────────────────────
{chr(10).join("  [+] " + d for d in done) or "  (nothing yet)"}

─── YOUR TASK ───────────────────────────────────────────────────
Write EXACTLY these files (no more, no less):
{chr(10).join("  " + f for f in be_files_needed)}

─── RULES ───────────────────────────────────────────────────────
- Follow the Prisma schema and enums defined above exactly.
- Every route must use auth middleware and filter by society_id.
- Use .env for all secrets. Never hardcode values.
- Follow the same pattern as backend/src/modules/auth/ (controller/service/routes split).

{FILE_FMT}

Now output every file listed above. Start immediately with the first // FILE: line.
"""
        ))

    # ── PHASE 2: Flutter Frontend ─────────────────────────────────
    if fe_pending:
        fe_files_needed = []
        for p in fe_pending:
            fe_files_needed.extend(FE_FILE_MAP.get(p, []))

        phases.append((
            "Flutter Developer",
            f"""You are an autonomous full-stack engineer executing the Society Manager project.

{master_prompt}

─── ALREADY BUILT (do NOT rewrite these) ────────────────────────
{chr(10).join("  [+] " + d for d in done) or "  (nothing yet)"}

─── YOUR TASK ───────────────────────────────────────────────────
Write EXACTLY these files (no more, no less):
{chr(10).join("  " + f for f in fe_files_needed)}

─── RULES ───────────────────────────────────────────────────────
- Flutter 3 + Riverpod + go_router + Dio.
- NEVER use raw Colors.*, TextStyle(), or hardcoded hex. Use AppColors.*, AppTextStyles.*.
- Every screen = ConsumerWidget with a matching StateNotifierProvider.
- API calls go through DioClient at lib/core/api/dio_client.dart.
- Always write the COMPLETE file — never truncate with "// ...".

{FILE_FMT}

Now output every file listed above. Start immediately with the first // FILE: line.
"""
        ))

    # ── PHASE 3: QA + Final Review (only when nothing left to build) ──
    if not be_pending and not fe_pending:
      phases.append((
        "QA and Reviewer",
        f"""You are the QA Engineer and final Reviewer for the Society Manager project.

{master_prompt}

─── CURRENT STATE ───────────────────────────────────────────────
Built so far:
{chr(10).join("  [+] " + d for d in done_list())}

Pending:
{chr(10).join("  [ ] " + p for p in pending_list()) or "  ALL COMPLETE"}

─── YOUR TASK ───────────────────────────────────────────────────
1. Review all backend modules: check society_id guard, auth middleware, input validation (zod).
2. Review Flutter screens: flag any raw Colors.* or missing error handling.
3. Fix any issues found using FILE: format below.
4. Write // FILE: STATUS.md summarising: what is built, env vars needed, how to run locally.
5. Write // FILE: DECISIONS.md documenting key technical decisions.

{FILE_FMT}
"""
      ))

    return phases


# ── Main ──────────────────────────────────────────────────────────

def main():
    # Argument parsing for selective rebuild
    parser = argparse.ArgumentParser(description='Run Society Manager pipeline with optional feature rebuild')
    parser.add_argument('--rebuild', nargs='*', help='Feature labels to force rebuild (e.g., "BE: Auth module" "FE: Auth screens")')
    args = parser.parse_args()
    # Store rebuild list globally for later use
    global REBUILD_FEATURES
    REBUILD_FEATURES = args.rebuild if args.rebuild else []
    # Check Ollama
    try:
        with urllib.request.urlopen("http://localhost:11434/api/tags", timeout=5) as r:
            tags = json.loads(r.read())
        names = [m["name"] for m in tags.get("models", [])]
        if not any(MODEL in n for n in names):
            print(f"[ERROR] Model '{MODEL}' not pulled.\nRun: ollama pull {MODEL}")
            sys.exit(1)
    except Exception as e:
        print(f"[ERROR] Ollama not reachable at localhost:11434\nRun: ollama serve\n{e}")
        sys.exit(1)

    # Load master prompt
    if not PROMPT_FILE.exists():
        print(f"[ERROR] Prompt file not found: {PROMPT_FILE}")
        sys.exit(1)
    master_prompt = PROMPT_FILE.read_text(encoding="utf-8")

    # Fresh session log, keep pipeline context across runs for resume
    SESSION_LOG.write_text("", encoding="utf-8")

    # Show initial state
    print_dashboard()
    pend = pending_list()
    if not pend:
        print("\n   ALL FEATURES COMPLETE! Nothing to do.")
        print("   Delete output files or features to re-run a phase.")
        return

    print(f"\n   {len(pend)} features pending — starting pipeline...\n")
    time.sleep(2)

    log("=== Pipeline start ===")
    max_rounds = 10  # safety cap — won't loop more than 10 times

    for round_num in range(1, max_rounds + 1):
        pend = pending_list()
        if not pend:
            break  # all done

        log(f"--- Round {round_num}: {len(pend)} pending ---")
        phases = build_phases(master_prompt)
        total  = len(phases)

        for i, (label, prompt) in enumerate(phases, start=1):
            try:
                run_phase(label, prompt, i, total)
            except KeyboardInterrupt:
                print("\n\n   [STOPPED] Pipeline interrupted.")
                log("Pipeline interrupted by user")
                sys.exit(0)

        # After each round, check if we made progress
        still = pending_list()
        if len(still) == len(pend):
            # No progress made — model didn't write any new files
            log(f"[WARN] Round {round_num} made no progress. Stopping.")
            print(f"\n   [WARN] No new files written in round {round_num}.")
            print("   The model may need a stronger prompt or the features need manual work.")
            break

    # Final dashboard
    print_dashboard()
    done_count = len(done_list())
    total_count = len(FEATURES)
    print(f"\n   PIPELINE COMPLETE: {done_count}/{total_count} features built.")
    still = pending_list()
    if still:
        print(f"   {len(still)} could not be auto-built:")
        for s in still:
            print(f"     [ ] {s}")
    else:
        print("   ALL FEATURES COMPLETE!")
    log("=== Pipeline complete ===")


if __name__ == "__main__":
    main()
