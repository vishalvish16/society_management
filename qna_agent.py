# ═══════════════════════════════════════════════════════════════════
#  SOCIETY MANAGER — QnA Agent + Code Fixer Integration
#  ─────────────────────────────────────────────────────────────────
#  HOW TO USE:
#    python qna_agent.py
#
#  The agent reads master_agent_prompt_v3.md to understand the full
#  system design, then answers your questions about any feature.
#  If it detects a bug in your question it automatically calls
#  code_fixer.py to fix it before answering.
# ═══════════════════════════════════════════════════════════════════

import os, sys, re, json, pathlib, subprocess, textwrap, socket
from datetime import datetime

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BASE        = pathlib.Path("e:/Society_Managment")
BACKEND     = BASE / "backend"
FRONTEND    = BASE / "frontend"
MASTER_DOC  = BASE / "master_agent_prompt_v3.md"
SCHEMA_FILE = BACKEND / "prisma" / "schema.prisma"
QNA_LOG     = BASE / "qna_session.log"

# ── Colour helpers (Windows-safe) ────────────────────────────────
try:
    import colorama; colorama.init()
    R="\033[91m"; G="\033[92m"; Y="\033[93m"; B="\033[94m"; M="\033[95m"; C="\033[96m"; W="\033[0m"
except ImportError:
    R=G=Y=B=M=C=W=""

# ── Logger ───────────────────────────────────────────────────────

def log(msg, colour=""):
    ts   = datetime.now().strftime("%H:%M:%S")
    line = f"[{ts}] {msg}"
    print(f"{colour}{line}{W}" if colour else line)
    with QNA_LOG.open("a", encoding="utf-8") as f:
        f.write(line + "\n")

def section(title):
    bar = "─" * max(0, 60 - len(title) - 4)
    print(f"\n{C}┌── {title} {bar}{W}")

# ── Load system knowledge ────────────────────────────────────────

class SystemKnowledge:
    """
    Loads master_agent_prompt_v3.md + schema.prisma and builds an
    in-memory knowledge base the QnA agent uses for answering.
    """

    def __init__(self):
        self.master   = self._load(MASTER_DOC)
        self.schema   = self._load(SCHEMA_FILE)
        self.models   = self._extract_models()
        self.features = self._extract_features()
        self.apis     = self._extract_apis()

    def _load(self, path: pathlib.Path) -> str:
        if path.exists():
            return path.read_text(encoding="utf-8", errors="replace")
        return ""

    def _extract_models(self) -> dict:
        """Parse schema.prisma → {modelName: [fieldName, ...]}"""
        models = {}
        cur_model = None
        for line in self.schema.splitlines():
            m = re.match(r'^model\s+(\w+)\s*\{', line)
            if m:
                cur_model = m.group(1)
                models[cur_model] = []
            elif cur_model and re.match(r'^\s+(\w+)\s+\w', line):
                field_m = re.match(r'^\s+(\w+)\s+', line)
                if field_m:
                    fname = field_m.group(1)
                    if not fname.startswith('//') and fname not in ('@@', ):
                        models[cur_model].append(fname)
            elif line.strip() == '}':
                cur_model = None
        return models

    def _extract_features(self) -> list:
        """Extract feature list from master doc."""
        features = []
        for line in self.master.splitlines():
            m = re.match(r'^\s*#{1,3}\s+(?:\d+\.?\d*\s+)?(.+)', line)
            if m and len(m.group(1)) < 80:
                features.append(m.group(1).strip())
        return features[:60]

    def _extract_apis(self) -> list:
        """Find all route definitions from JS files."""
        apis = []
        routes_dir = BACKEND / "src"
        if routes_dir.exists():
            for f in routes_dir.rglob("*.routes.js"):
                content = f.read_text(encoding="utf-8", errors="replace")
                for m in re.finditer(r'router\.(get|post|put|patch|delete)\([\'"]([^\'"]+)[\'"]', content):
                    apis.append(f"{m.group(1).upper()} {m.group(2)} ({f.stem})")
        return apis

    def model_fields(self, model_name: str) -> list:
        """Get fields for a model (case-insensitive lookup)."""
        for k, v in self.models.items():
            if k.lower() == model_name.lower():
                return v
        return []

    def search(self, query: str) -> list:
        """Return relevant lines from master doc matching the query."""
        words   = [w.lower() for w in re.split(r'\W+', query) if len(w) > 2]
        lines   = self.master.splitlines()
        scored  = []
        for i, line in enumerate(lines):
            ll = line.lower()
            score = sum(1 for w in words if w in ll)
            if score > 0:
                # Include surrounding context (3 lines)
                start = max(0, i - 1)
                end   = min(len(lines), i + 4)
                scored.append((score, "\n".join(lines[start:end])))
        scored.sort(key=lambda x: -x[0])
        seen = set()
        results = []
        for _, text in scored[:8]:
            if text not in seen:
                seen.add(text)
                results.append(text)
        return results

# ── Bug detector ─────────────────────────────────────────────────

class BugDetector:
    """
    Analyses a user question for keywords that indicate a real runtime bug
    that code_fixer.py should handle.
    """

    BUG_PATTERNS = [
        # HTTP errors
        (r'\b500\b',                     "500 Internal Server Error"),
        (r'\b404\b',                     "404 Not Found"),
        (r'\b401\b',                     "401 Unauthorized"),
        (r'\b403\b',                     "403 Forbidden"),
        # Prisma
        (r'unknown field',               "Prisma unknown field"),
        (r'prisma.*validat',             "PrismaClientValidationError"),
        (r'p2002',                       "Prisma unique constraint"),
        (r'p2025',                       "Prisma record not found"),
        (r'prisma.*error',               "Prisma error"),
        # Node/Express
        (r'cannot read prop',            "TypeError: Cannot read property"),
        (r'is not a function',           "TypeError: not a function"),
        (r'module not found',            "Module not found"),
        (r'eperm',                       "EPERM file permission error"),
        # Flutter
        (r'flutter.*error',              "Flutter error"),
        (r'null.*check.*operator',       "Null check operator on null"),
        (r'setState.*unmounted',         "setState on unmounted widget"),
        (r'undefined.*widget',           "Undefined widget reference"),
        # Auth
        (r'jwt.*invalid',                "JWT invalid"),
        (r'jwt.*expired',                "JWT expired"),
        (r'token.*null',                 "Token is null"),
        # DB
        (r'migration.*fail',             "Migration failure"),
        (r'column.*does not exist',      "DB column missing"),
        (r'relation.*does not exist',    "DB table/relation missing"),
    ]

    def __init__(self, question: str):
        self.question = question.lower()
        self.bugs     = self._detect()

    def _detect(self) -> list:
        found = []
        for pattern, label in self.BUG_PATTERNS:
            if re.search(pattern, self.question, re.IGNORECASE):
                found.append(label)
        return found

    @property
    def has_bug(self) -> bool:
        return len(self.bugs) > 0

    def summary(self) -> str:
        return ", ".join(self.bugs)

# ── Code fixer bridge ─────────────────────────────────────────────

def call_code_fixer(question: str, bug_summary: str):
    """
    Write the question to fix.py PROMPT variable and run fix.py,
    which in turn calls code_fixer.py.
    """
    section("Code Fixer Triggered")
    log(f"Bug(s) detected: {bug_summary}", R)
    log("Calling code_fixer.py to fix the issue...", Y)

    # Write prompt to the prompt file so fix.py picks it up
    prompt_file = BASE / "prompt"
    prompt_file.write_text(
        f"[QnA Agent auto-fix]\nUser question: {question}\nDetected bugs: {bug_summary}\n",
        encoding="utf-8"
    )

    fix_py = BASE / "fix.py"
    if not fix_py.exists():
        log("  fix.py not found — calling code_fixer.py directly", Y)
        rc = subprocess.call([sys.executable, str(BASE / "code_fixer.py")], cwd=str(BASE))
    else:
        rc = subprocess.call([sys.executable, str(fix_py)], cwd=str(BASE))

    if rc == 0:
        log("Code fixer completed successfully.", G)
    else:
        log(f"Code fixer exited with code {rc}. Check fixer.log for details.", R)
    return rc

# ── Answer engine ─────────────────────────────────────────────────

class AnswerEngine:
    """
    Builds an answer for a question using the SystemKnowledge base.
    No external LLM needed — pure rule-based + document retrieval.
    """

    def __init__(self, knowledge: SystemKnowledge):
        self.k = knowledge

    def answer(self, question: str) -> str:
        q = question.lower()
        parts = []

        # ── Model/field questions ──────────────────────────────
        model_q = re.search(r'\b(plan|society|user|unit|bill|expense|visitor|complaint|staff|'
                             r'delivery|vehicle|amenity|booking|notice|notification|'
                             r'gatepass|gate_pass|domestic|moveRequest|move_request|'
                             r'subscriptionpayment|parking)\b', q)
        if model_q:
            model_name = model_q.group(1).replace("_", "")
            # fuzzy match to actual model names
            matches = [k for k in self.k.models if model_name in k.lower()]
            if matches:
                for m in matches[:2]:
                    fields = self.k.models[m]
                    parts.append(f"**{m}** model fields ({len(fields)} total):")
                    parts.append("  " + ", ".join(fields))

        # ── API route questions ────────────────────────────────
        if any(w in q for w in ("api", "route", "endpoint", "url", "path")):
            rel_apis = [a for a in self.k.apis
                        if any(w in a.lower() for w in q.split() if len(w) > 3)]
            if rel_apis:
                parts.append("\n**Relevant API routes:**")
                for a in rel_apis[:10]:
                    parts.append(f"  {a}")

        # ── Feature/design questions — search master doc ───────
        relevant = self.k.search(question)
        if relevant:
            parts.append("\n**From system design (master_agent_prompt_v3.md):**")
            for r in relevant[:4]:
                parts.append(textwrap.indent(r.strip(), "  "))

        # ── Fallback ───────────────────────────────────────────
        if not parts:
            parts.append("No specific match found in system knowledge.")
            parts.append("Try asking about: model fields, API routes, auth flow, billing, visitors, complaints, staff, amenities, gate passes, notifications.")
            if self.k.features:
                parts.append("\nKnown system features:")
                for f in self.k.features[:15]:
                    parts.append(f"  • {f}")

        return "\n".join(parts)

# ── Backend health check ──────────────────────────────────────────

def backend_running() -> bool:
    s = socket.socket()
    s.settimeout(0.5)
    result = s.connect_ex(('localhost', 3000)) == 0
    s.close()
    return result

# ── Interactive loop ──────────────────────────────────────────────

HELP_TEXT = """
  Commands:
    ask  <question>   — Ask anything about the system
    fix  <issue>      — Directly trigger code_fixer with a description
    models            — List all Prisma models
    fields <Model>    — Show fields of a specific model
    apis              — List all discovered API routes
    health            — Check if backend is running on :3000
    help              — Show this help
    exit / quit       — Exit the agent
"""

def run_agent():
    QNA_LOG.write_text("", encoding="utf-8")

    print(f"\n{M}{'═'*62}")
    print("   SOCIETY MANAGER — QnA AGENT + CODE FIXER")
    print(f"{'═'*62}{W}")
    print(f"\n  Loading system knowledge from master_agent_prompt_v3.md...")

    kb = SystemKnowledge()
    engine = AnswerEngine(kb)

    print(f"{G}  ✓ Loaded {len(kb.models)} models, {len(kb.apis)} routes, {len(kb.features)} features{W}")
    print(f"\n  Type a question, 'fix <issue>', or 'help' for commands.\n")

    while True:
        try:
            raw = input(f"{Y}QnA> {W}").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye.")
            break

        if not raw:
            continue

        cmd_parts = raw.split(None, 1)
        cmd       = cmd_parts[0].lower()
        rest      = cmd_parts[1] if len(cmd_parts) > 1 else ""

        log(f"USER: {raw}")

        # ── Built-in commands ──────────────────────────────────

        if cmd in ("exit", "quit", "q"):
            print("Goodbye.")
            break

        elif cmd == "help":
            print(HELP_TEXT)

        elif cmd == "models":
            section("Prisma Models")
            for name, fields in kb.models.items():
                print(f"  {G}{name}{W} ({len(fields)} fields)")

        elif cmd == "fields":
            if not rest:
                print("  Usage: fields <ModelName>")
            else:
                fields = kb.model_fields(rest.strip())
                if fields:
                    section(f"Fields: {rest.strip()}")
                    print("  " + ", ".join(fields))
                else:
                    print(f"  Model '{rest}' not found. Try: models")

        elif cmd == "apis":
            section("API Routes")
            if kb.apis:
                for a in kb.apis:
                    print(f"  {a}")
            else:
                print("  No route files found yet. Build the backend first.")

        elif cmd == "health":
            running = backend_running()
            status  = f"{G}RUNNING on :3000{W}" if running else f"{R}NOT running{W}"
            print(f"  Backend: {status}")

        elif cmd == "fix":
            question = rest or raw
            rc = call_code_fixer(question, "manual fix request")
            log(f"FIXER: exit={rc}")

        else:
            # ── Treat as a question ────────────────────────────
            question = raw

            # 1. Bug detection
            detector = BugDetector(question)
            if detector.has_bug:
                log(f"Bug detected: {detector.summary()}", R)
                print(f"\n  {R}⚠  Bug detected:{W} {detector.summary()}")
                print(f"  {Y}→ Triggering code_fixer.py automatically...{W}\n")
                call_code_fixer(question, detector.summary())

            # 2. Answer the question regardless
            section("Answer")
            answer = engine.answer(question)
            print(answer)
            log(f"ANSWER: {answer[:200]}")

        print()


if __name__ == "__main__":
    run_agent()
