# e:\Society_Managment\ui_run.py
# ─────────────────────────────────────────────────────────────────
# Society Manager — UI/UX Agent Runner v1.0
# Rewrites every Flutter screen with production-quality UI/UX.
# Uses the best available offline model; pulls one if needed.
# ─────────────────────────────────────────────────────────────────
import pathlib, sys, os, re, json, time, threading, urllib.request, urllib.error
from datetime import datetime

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# ── Paths ────────────────────────────────────────────────────────
BASE_DIR     = pathlib.Path("e:/Society_Managment")
FRONTEND_DIR = BASE_DIR / "frontend"
SESSION_LOG  = BASE_DIR / "ui_session.log"
OLLAMA_URL   = "http://localhost:11434/api/generate"
OLLAMA_PULL  = "http://localhost:11434/api/pull"

# ── Model preference (best for code/UI, in priority order) ───────
# deepseek-coder-v2 is excellent for Flutter UI generation.
# We fall back to what's already pulled if preferred not available.
PREFERRED_MODELS = [
    "deepseek-coder-v2:16b",   # best offline code+UI model
    "deepseek-coder:6.7b",     # smaller but still strong
    "qwen2.5-coder:14b",       # already pulled, good fallback
    "qwen2.5:14b",             # general fallback
    "mistral:7b",              # lightweight fallback
]

# ── Screens to rebuild with great UI/UX ──────────────────────────
# Each entry: (feature_label, screen_path, description_for_model)
SCREENS = [
    (
        "Login Screen",
        "lib/features/auth/screens/login_screen.dart",
        "Society Manager login. Fields: phone + password. Buttons: Login, Forgot Password, Register. Show society logo at top. Clean card layout centered on screen.",
    ),
    (
        "Register Screen",
        "lib/features/auth/screens/register_screen.dart",
        "New resident registration. Fields: name, phone, email, password, confirm password, unit number. Step-by-step or scrollable form. Validation feedback inline.",
    ),
    (
        "Forgot Password Screen",
        "lib/features/auth/screens/forgot_password_screen.dart",
        "Forgot password via phone OTP. Step 1: enter phone. Step 2: enter OTP (use Pinput widget). Step 3: new password + confirm.",
    ),
    (
        "Dashboard Screen",
        "lib/features/dashboard/screens/dashboard_screen.dart",
        "Society admin dashboard. Stat cards: Total Units, Pending Bills, Open Complaints, Active Visitors. Quick action buttons. Recent activity feed. Responsive grid (1 col mobile, 2 col tablet, 4 col desktop).",
    ),
    (
        "Super Admin Dashboard",
        "lib/features/dashboard/screens/super_admin_dashboard.dart",
        "Super-admin overview. Stat cards: Total Societies, Active Plans, Revenue, Expiring Soon. Society list table with search and filter by plan/status. Actions: View, Suspend, Delete.",
    ),
    (
        "SA Dashboard Screen",
        "lib/features/superadmin/screens/sa_dashboard_screen.dart",
        "Full super-admin panel. Tabs: Societies, Plans, Subscriptions. Each tab has a data table with pagination, search bar, and action buttons. Use shimmer loading.",
    ),
    (
        "Members Screen",
        "lib/features/members/screens/members_screen.dart",
        "Resident members list. Search bar + filter by unit/wing. List tiles with avatar, name, unit, role badge. FAB to add member. Tap to view/edit profile.",
    ),
    (
        "Bills Screen",
        "lib/features/bills/screens/bills_screen.dart",
        "Maintenance bills list. Filter: all/pending/paid/overdue tabs. Bill card: unit, amount, month, status chip, due date. Pull to refresh. FAB to generate bills.",
    ),
    (
        "Expenses Screen",
        "lib/features/expenses/screens/expenses_screen.dart",
        "Society expenses list. Category filter chips (maintenance, utilities, events...). Expense card: title, amount, category chip, date, status badge. FAB to add expense.",
    ),
    (
        "Complaints Screen",
        "lib/features/complaints/screens/complaints_screen.dart",
        "Complaints list. Status tabs: Open, In Progress, Resolved. Complaint card: category icon, title, unit, date, priority badge. FAB to raise complaint. Tap to view thread.",
    ),
    (
        "Visitors Screen",
        "lib/features/visitors/screens/visitors_screen.dart",
        "Visitor log. Tabs: Today, History. Visitor card: name, host unit, purpose, time, status chip. Search bar. Guard can scan QR via camera button.",
    ),
    (
        "Notices Screen",
        "lib/features/notices/screens/notices_screen.dart",
        "Society notices/announcements. Notice card: title, preview text, date, author. Category filter chips. FAB to post notice. Tap to read full notice.",
    ),
    (
        "Amenities Screen",
        "lib/features/amenities/screens/amenities_screen.dart",
        "Amenity booking. Grid of amenity cards: gym, pool, clubhouse, etc. Each card: name, status chip, availability times. Tap to book. My Bookings tab with cancel option.",
    ),
    (
        "Notifications Screen",
        "lib/features/notifications/screens/notifications_screen.dart",
        "Notification inbox. List of notification tiles: icon by type, title, message preview, time ago. Mark all read button. Swipe to dismiss. Empty state illustration.",
    ),
    (
        "Staff Screen",
        "lib/features/staff/screens/staff_screen.dart",
        "Staff management. List: name, role, shift, today status badge (present/absent). Mark attendance button. FAB to add staff. Attendance history per staff.",
    ),
    (
        "Gate Pass Screen",
        "lib/features/gatepasses/screens/gate_pass_screen.dart",
        "Gate pass management. List of passes: visitor name, unit, validity, status chip. Generate pass button. QR scanner for guard to verify. Pass detail bottom sheet.",
    ),
    (
        "Domestic Help Screen",
        "lib/features/domestichelp/screens/domestic_help_screen.dart",
        "Domestic help registry. List: helper name, type (maid/cook/driver), unit, entry code, status badge. Pinput for code entry. Mark entry/exit. Scan QR option.",
    ),
    (
        "Delivery Screen",
        "lib/features/deliveries/screens/delivery_screen.dart",
        "Package deliveries list. Filter: pending/collected/left at gate. Delivery card: recipient unit, courier, time, status. Log delivery button. Notify resident button.",
    ),
    (
        "Vehicles Screen",
        "lib/features/vehicles/screens/vehicles_screen.dart",
        "Vehicle registry. List: number plate, type icon, owner unit, parking slot. Search by plate. FAB to register vehicle. Edit/remove swipe actions.",
    ),
    (
        "Plans Screen",
        "lib/features/plans/screens/plans_screen.dart",
        "Subscription plans page (super-admin). Plan cards: name, price/month, price/year, max units, features list. Highlight recommended plan. Edit plan button.",
    ),
    (
        "Societies Screen",
        "lib/features/societies/screens/societies_screen.dart",
        "Societies list (super-admin). Search + filter by plan/status. Society card: name, city, plan badge, unit count, status chip. FAB to add society. Tap to manage.",
    ),
    (
        "Units Screen",
        "lib/features/units/screens/units_screen.dart",
        "Unit management. Wing/floor filter. Unit card: unit code, status chip (occupied/vacant), resident count. FAB to add unit. Tap to view residents and bills.",
    ),
    (
        "Subscriptions Screen",
        "lib/features/subscriptions/screens/subscriptions_screen.dart",
        "Subscription payments list (super-admin). Filter by status/plan. Row: society name, plan, amount, date, status badge. Export CSV button. Pagination.",
    ),
]

# ── Utilities ─────────────────────────────────────────────────────

def log(msg):
    ts = datetime.now().strftime("[%H:%M:%S]")
    line = f"{ts} {msg}\n"
    with SESSION_LOG.open("a", encoding="utf-8") as f:
        f.write(line)

def ollama_models():
    """Return list of pulled model names."""
    try:
        with urllib.request.urlopen("http://localhost:11434/api/tags", timeout=5) as r:
            return [m["name"] for m in json.loads(r.read()).get("models", [])]
    except Exception:
        return []

def pick_model():
    """Return best available model name; pull one if none available."""
    pulled = ollama_models()
    if not pulled:
        print("[ERROR] Ollama not reachable. Run: ollama serve")
        sys.exit(1)

    for preferred in PREFERRED_MODELS:
        # Check exact match or prefix match (e.g. "qwen2.5-coder:14b" in "qwen2.5-coder:14b-instruct-q4")
        for name in pulled:
            if preferred in name or name.startswith(preferred.split(":")[0]):
                print(f"[MODEL] Using: {name}")
                log(f"Model selected: {name}")
                return name

    # None of preferred are pulled — pull the best one available offline
    to_pull = PREFERRED_MODELS[0]
    print(f"\n[MODEL] No preferred UI model found. Pulling: {to_pull}")
    print("        This may take 10-30 minutes depending on your internet speed.")
    print("        Press Ctrl+C to cancel and use existing model instead.\n")
    try:
        pull_model(to_pull)
        return to_pull
    except KeyboardInterrupt:
        # Fall back to whatever is pulled
        fallback = pulled[0]
        print(f"\n[MODEL] Pull cancelled. Falling back to: {fallback}")
        log(f"Pull cancelled, fallback: {fallback}")
        return fallback

def pull_model(model_name):
    """Stream-pull a model from Ollama registry."""
    payload = json.dumps({"name": model_name, "stream": True}).encode()
    req = urllib.request.Request(
        OLLAMA_PULL, data=payload,
        headers={"Content-Type": "application/json"}, method="POST"
    )
    last_status = ""
    try:
        with urllib.request.urlopen(req, timeout=3600) as resp:
            for raw in resp:
                try:
                    obj = json.loads(raw.decode("utf-8").strip())
                except Exception:
                    continue
                status = obj.get("status", "")
                total  = obj.get("total", 0)
                completed = obj.get("completed", 0)
                if status != last_status:
                    if total:
                        pct = int(completed / total * 100) if total > 0 else 0
                        print(f"\r   {status}: {pct}%    ", end="", flush=True)
                    else:
                        print(f"\r   {status}    ", end="", flush=True)
                    last_status = status
                if obj.get("status") == "success":
                    print(f"\n[PULL] {model_name} ready.")
                    return
    except urllib.error.URLError as e:
        print(f"\n[ERROR] Pull failed: {e}")
        sys.exit(1)

def ask_model(model, prompt):
    """Stream model output, return full text."""
    payload = json.dumps({"model": model, "prompt": prompt, "stream": True}).encode()
    req = urllib.request.Request(
        OLLAMA_URL, data=payload,
        headers={"Content-Type": "application/json"}, method="POST"
    )
    chunks = []
    first = True
    stop = threading.Event()

    def spin():
        frames = ["|", "/", "-", "\\"]
        i = 0
        while not stop.is_set():
            sys.stdout.write(f"\r   Generating... {frames[i % 4]}  ")
            sys.stdout.flush()
            time.sleep(0.15)
            i += 1

    t = threading.Thread(target=spin, daemon=True)
    t.start()
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            for raw in resp:
                try:
                    obj = json.loads(raw.decode("utf-8").strip())
                except Exception:
                    continue
                tok = obj.get("response", "")
                if tok:
                    if first:
                        stop.set(); t.join()
                        sys.stdout.write("\r" + " " * 50 + "\r")
                        sys.stdout.flush()
                        first = False
                    try:
                        sys.stdout.write(tok)
                        sys.stdout.flush()
                    except UnicodeEncodeError:
                        sys.stdout.write(tok.encode("ascii", "replace").decode())
                        sys.stdout.flush()
                    chunks.append(tok)
                if obj.get("done"):
                    print()
                    break
    except urllib.error.URLError as e:
        stop.set()
        print(f"\n[FATAL] Ollama unreachable: {e}")
        sys.exit(1)

    return "".join(chunks)

def clean_output(text: str) -> str:
    text = re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', text)
    text = re.sub(r'\x1b[()][AB012]', '', text)
    text = re.sub(r'[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]\s*', '', text)
    text = re.sub(r'\r', '', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()

def extract_dart_code(text: str) -> str:
    """Extract the Dart code block from model output."""
    # Try fenced code block first
    patterns = [
        re.compile(r'```dart\n(.*?)```', re.DOTALL),
        re.compile(r'```\n(.*?)```', re.DOTALL),
        # FILE: format
        re.compile(r'// FILE:[^\n]*\n```[^\n]*\n(.*?)```', re.DOTALL),
    ]
    for pat in patterns:
        m = pat.search(text)
        if m:
            return m.group(1).strip()
    # If no code block found, return raw (model might have output bare code)
    return text.strip()

def screen_done(path: str) -> bool:
    """Check if this screen already has rich UI (more than 50 lines = not a stub)."""
    full = FRONTEND_DIR / path
    if not full.exists():
        return False
    lines = full.read_text(encoding="utf-8", errors="replace").splitlines()
    return len(lines) > 60  # stubs are < 30 lines; real UI screens are 60+

def print_dashboard(current="", done=0, total=0):
    os.system('cls' if os.name == 'nt' else 'clear')
    print("=" * 72)
    print("   SOCIETY MANAGER  --  UI/UX AGENT PIPELINE")
    print("=" * 72)
    if current:
        filled = int((done / total) * 40) if total else 0
        bar = "#" * filled + "-" * (40 - filled)
        print(f"   Progress : [{bar}] {done}/{total}")
        print(f"   Screen   : {current}")
    print(f"   Time     : {datetime.now().strftime('%H:%M:%S')}")
    print("-" * 72)
    for i, (label, path, _) in enumerate(SCREENS):
        full = FRONTEND_DIR / path
        if full.exists():
            lines = full.read_text(encoding="utf-8", errors="replace").splitlines()
            rich = len(lines) > 60
        else:
            rich = False
        status = "[+]" if rich else "[ ]"
        marker = " <-- RUNNING" if label == current else ""
        print(f"   {status} {label:<35}{marker}")
    print("=" * 72)
    if current:
        print("   LIVE OUTPUT:")
        print("-" * 72)

# ── Design system reference (injected into every prompt) ─────────

DESIGN_SYSTEM = """
DESIGN SYSTEM (MANDATORY — never deviate):
- Colors:   AppColors.primary (#1E3A8A), AppColors.primaryLight (#3B82F6)
            AppColors.secondary (#10B981), AppColors.background (#F8FAFC)
            AppColors.surface (white), AppColors.textMain (#0F172A)
            AppColors.textMuted (#64748B), AppColors.error (#EF4444)
            AppColors.warning (#F59E0B), AppColors.info (#3B82F6)
- Imports:  import '../../../core/theme/app_colors.dart';  (adjust depth as needed)
            import '../../../core/theme/app_text_styles.dart';
- NEVER use Colors.blue, Color(0xFF...) inline, TextStyle() with raw values.
  Always use AppColors.* and AppTextStyles.*.
- Use google_fonts for typography if AppTextStyles not yet defined.
- Use shimmer package for loading states.
- Use flutter_animate for micro-animations (FadeIn, SlideY).
- Cards: elevation 0, border Color(0xFFE2E8F0), radius 12.
- Spacing: 8/12/16/24/32 px grid.
- Responsive: MediaQuery width >= 1200 => 4 col, >= 768 => 2 col, else 1 col.
- ConsumerWidget with WidgetRef ref (Riverpod v2 — NOT ScopedReader).
- Import paths use relative paths from the screen file location.
"""

FILE_FMT = """
OUTPUT FORMAT (mandatory):
Output the complete Dart file inside a single code block:
```dart
<complete file — never truncate>
```
Do NOT output anything after the closing ```.
Do NOT add explanations outside the code block.
"""

# ── Main ──────────────────────────────────────────────────────────

def main():
    # Verify Ollama is running
    try:
        urllib.request.urlopen("http://localhost:11434/api/tags", timeout=5)
    except Exception as e:
        print(f"[ERROR] Ollama not reachable: {e}\nRun: ollama serve")
        sys.exit(1)

    SESSION_LOG.write_text("", encoding="utf-8")
    model = pick_model()

    pending = [(label, path, desc) for label, path, desc in SCREENS if not screen_done(path)]
    already_done = len(SCREENS) - len(pending)

    print_dashboard()
    print(f"\n   {already_done}/{len(SCREENS)} screens already have rich UI.")
    print(f"   {len(pending)} screens need UI/UX upgrade.\n")
    if not pending:
        print("   ALL SCREENS ALREADY UPGRADED!")
        print("   Delete a screen file or truncate it to force a re-run.")
        return
    time.sleep(2)

    log(f"=== UI/UX Pipeline start | model={model} ===")
    done_count = already_done

    for i, (label, path, description) in enumerate(pending, start=1):
        screen_file = FRONTEND_DIR / path

        # Compute relative import depth
        # e.g. lib/features/auth/screens/login_screen.dart -> depth 3 from lib/
        parts = path.split("/")  # ['lib','features','auth','screens','file.dart']
        depth = len(parts) - 2   # how many levels up to reach lib/
        rel_prefix = "../" * depth

        print_dashboard(label, done_count, len(SCREENS))
        log(f"START: {label} ({path})")

        prompt = f"""You are a senior Flutter UI/UX engineer. Write a production-quality Flutter screen.

SCREEN: {label}
PURPOSE: {description}

{DESIGN_SYSTEM}

ADDITIONAL RULES:
- File path will be saved at: frontend/{path}
- Relative import prefix from this file to lib/: {rel_prefix}
  Example imports:
    import '{rel_prefix}core/theme/app_colors.dart';
    import '{rel_prefix}core/theme/app_text_styles.dart';
    import '{rel_prefix}core/api/dio_client.dart';
  For providers in the same feature:
    import '../providers/<feature>_provider.dart';
- Every screen must be a ConsumerWidget (flutter_riverpod ^2.5.0).
- Use WidgetRef ref — never ScopedReader.
- Show realistic mock data if provider not yet wired (AsyncValue.data(...)).
- Include: AppBar (or custom header), loading state (shimmer or CircularProgressIndicator),
  error state (retry button), empty state (icon + text), main content.
- Use these widgets where appropriate:
    shimmer (loading), flutter_animate (FadeIn/SlideY on list items),
    go_router context.go('/route') for navigation,
    Pinput for OTP fields, fl_chart for any charts,
    table_calendar for date pickers, qr_flutter for QR display.
- No placeholder TODO comments — write real working code.
- Write the FULL file. Never truncate.

{FILE_FMT}
"""

        raw = ask_model(model, prompt)
        raw = clean_output(raw)

        dart_code = extract_dart_code(raw)

        if len(dart_code) < 200:
            log(f"  [WARN] Short output for {label} ({len(dart_code)} chars) — may be incomplete")
            print(f"\n   [WARN] Output was very short ({len(dart_code)} chars). Saving anyway.")

        # Write the screen file
        screen_file.parent.mkdir(parents=True, exist_ok=True)
        screen_file.write_text(dart_code, encoding="utf-8")
        log(f"  [WROTE] frontend/{path} ({len(dart_code)} chars)")

        # Also save raw output for inspection
        out_file = BASE_DIR / f"ui_output_{label.lower().replace(' ', '_')}.txt"
        out_file.write_text(
            f"# UI/UX Agent Output: {label}\n"
            f"# Model: {model}\n"
            f"# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
            f"{'=' * 60}\n\n{raw}\n",
            encoding="utf-8"
        )

        done_count += 1
        log(f"DONE:  {label} ({done_count}/{len(SCREENS)})")
        print(f"\n   [DONE] {label} saved. ({done_count}/{len(SCREENS)} total)")
        time.sleep(1)

    # Final summary
    print_dashboard()
    print(f"\n   UI/UX PIPELINE COMPLETE: {done_count}/{len(SCREENS)} screens done.")
    print(f"   Run: cd frontend && flutter run -d chrome")
    print(f"   Log: {SESSION_LOG}")
    log("=== UI/UX Pipeline complete ===")


if __name__ == "__main__":
    main()
