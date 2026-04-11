# e:\Society_Managment\code_fixer.py
# ═══════════════════════════════════════════════════════════════════
#  SOCIETY MANAGER — AUTONOMOUS AI AGENT  v5.0
#  Works like Cursor / Claude agent mode:
#    1. Read `prompt` file — understand intent (bug fix OR feature)
#    2. Plan — ask Ollama what needs to change across ALL layers
#    3. Discover — find every linked file (DB, backend, frontend)
#    4. Implement — diagnose + fix/enhance each file with quality
#    5. Verify — syntax check, prisma validate, flutter analyze
#    6. Restart — reload PM2 so changes are live
#  If no prompt → standard maintenance pass (prisma + flutter checks)
# ═══════════════════════════════════════════════════════════════════

import os, sys, re, json, subprocess, pathlib, shutil, socket, time
from datetime import datetime

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BASE     = pathlib.Path("e:/Society_Managment")
BACKEND  = BASE / "backend"
FRONTEND = BASE / "frontend"
SCHEMA   = BACKEND / "prisma" / "schema.prisma"
LOG_FILE = BASE / "fixer.log"
PROMPT_FILE = BASE / "prompt"

# ─────────────────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────────────────

def log(msg: str, level: str = ""):
    ts   = datetime.now().strftime("%H:%M:%S")
    tag  = f"[{level}] " if level else ""
    line = f"[{ts}] {tag}{msg}"
    print(line)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(line + "\n")

def header(title: str):
    bar = "═" * max(0, 62 - len(title) - 4)
    log(f"\n╔══ {title} {bar}")

def section(title: str):
    bar = "─" * max(0, 60 - len(title) - 4)
    log(f"\n┌── {title} {bar}")

# ─────────────────────────────────────────────────────────────────
# SHELL
# ─────────────────────────────────────────────────────────────────

def run(cmd: str, cwd=None) -> tuple:
    cwd = str(cwd or BASE)
    try:
        r = subprocess.run(
            cmd, cwd=cwd, shell=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            encoding="utf-8", errors="replace",
        )
        return (r.stdout or ""), (r.stderr or ""), r.returncode
    except Exception as e:
        return "", str(e), 1

def port_in_use(port: int) -> bool:
    s = socket.socket()
    s.settimeout(0.5)
    result = s.connect_ex(("localhost", port)) == 0
    s.close()
    return result

# ─────────────────────────────────────────────────────────────────
# OLLAMA CLIENT
# ─────────────────────────────────────────────────────────────────

OLLAMA_URL    = "http://localhost:11434"
PREFER_MODELS = [
    "qwen2.5-coder:14b", "qwen2.5-coder:7b",
    "qwen2.5:14b",        "qwen2.5:7b",
    "deepseek-coder:6.7b","llama3:8b",
    "mistral:7b",         "llama3.2:3b",
]

class Ollama:
    def __init__(self):
        self._model       = None
        self._tok_per_sec = None   # measured at first call

    def _pick_model(self) -> str | None:
        import urllib.request
        try:
            with urllib.request.urlopen(f"{OLLAMA_URL}/api/tags", timeout=5) as r:
                data     = json.loads(r.read())
                installed = {m["name"] for m in data.get("models", [])}
                base_map  = {}
                for m in data.get("models", []):
                    base_map.setdefault(m["name"].split(":")[0], m["name"])
                for pref in PREFER_MODELS:
                    if pref in installed:
                        return pref
                    base = pref.split(":")[0]
                    if base in base_map:
                        return base_map[base]
                if data.get("models"):
                    return data["models"][0]["name"]
        except Exception as e:
            log(f"Ollama not reachable: {e}", "WARN")
        return None

    def _measure_speed(self):
        """Measure tokens/sec via streaming to avoid blocking timeout."""
        import urllib.request
        body = json.dumps({
            "model": self._model, "prompt": "Say: ok",
            "stream": True, "options": {"num_predict": 8},
        }).encode()
        req = urllib.request.Request(f"{OLLAMA_URL}/api/generate", data=body)
        req.add_header("Content-Type", "application/json")
        try:
            t0 = time.time()
            tok_count = 0
            # Use a long socket timeout (300s) so prompt eval doesn't kill us
            with urllib.request.urlopen(req, timeout=300) as r:
                for raw_line in r:
                    chunk = json.loads(raw_line.decode("utf-8", errors="replace").strip() or "{}")
                    tok_count += len(chunk.get("response", "").split())
                    if chunk.get("done"):
                        eval_dur = chunk.get("eval_duration", 0) / 1e9
                        eval_cnt = chunk.get("eval_count", tok_count)
                        if eval_dur > 0:
                            self._tok_per_sec = max(eval_cnt / eval_dur, 1.0)
                        else:
                            elapsed = time.time() - t0
                            self._tok_per_sec = max(eval_cnt / max(elapsed, 0.1), 1.0)
                        break
            log(f"Model speed: {self._tok_per_sec:.1f} tok/s (calibrated)", "AI")
        except Exception as e:
            log(f"Speed calibration failed ({e}), using 4 tok/s default", "WARN")
            self._tok_per_sec = 4.0   # conservative fallback for 14b models

    def _timeout_for(self, max_output_tokens: int, input_chars: int) -> int:
        """
        Calculate a realistic timeout based on model speed.
        input_chars → rough token count (1 token ≈ 4 chars).
        Adds time for prompt evaluation (slower than generation).
        """
        if self._tok_per_sec is None:
            return 600   # before calibration, be generous
        input_tokens  = input_chars // 4
        # prompt eval ≈ half generation speed
        prompt_time   = input_tokens  / max(self._tok_per_sec * 0.5, 1)
        gen_time      = max_output_tokens / self._tok_per_sec
        return min(int(prompt_time + gen_time + 15), 600)  # cap at 10min

    @property
    def model(self) -> str | None:
        if self._model is None:
            self._model = self._pick_model()
            if self._model:
                log(f"Ollama model: {self._model}", "AI")
                self._measure_speed()
        return self._model

    def ask(self, prompt: str, max_tokens: int = 2048) -> str:
        """
        Stream the response token-by-token.
        Uses a large socket timeout (300s) so prompt evaluation doesn't kill us.
        Returns full response text. Empty string on failure.
        """
        if not self.model:
            return ""
        import urllib.request
        # Log estimated work
        est_input_toks = len(prompt) // 4
        log(f"  Calling Ollama (~{est_input_toks} input tokens, max_out={max_tokens})...", "AI")
        body = json.dumps({
            "model":   self.model,
            "prompt":  prompt,
            "stream":  True,
            "options": {"temperature": 0.05, "num_predict": max_tokens},
        }).encode()
        req = urllib.request.Request(f"{OLLAMA_URL}/api/generate", data=body)
        req.add_header("Content-Type", "application/json")
        try:
            parts = []
            # timeout=300: socket-level timeout. Between streaming tokens this is fine;
            # the initial prompt-eval phase may be slow but will send first token within this window.
            with urllib.request.urlopen(req, timeout=300) as r:
                for raw_line in r:
                    line = raw_line.decode("utf-8", errors="replace").strip()
                    if not line:
                        continue
                    try:
                        chunk = json.loads(line)
                        parts.append(chunk.get("response", ""))
                        if chunk.get("done"):
                            break
                    except Exception:
                        continue
            result = "".join(parts).strip()
            log(f"  → {len(result)} chars received", "AI")
            return result
        except Exception as e:
            log(f"Ollama call failed: {e}", "WARN")
            return ""

    def ask_json(self, prompt: str, max_tokens: int = 512) -> dict | list | None:
        """Ask and parse JSON from the response."""
        raw = self.ask(prompt, max_tokens)
        if not raw:
            return None
        # Extract first JSON object or array
        m = re.search(r"(\{[\s\S]*\}|\[[\s\S]*\])", raw)
        if not m:
            return None
        try:
            return json.loads(m.group(1))
        except Exception:
            return None

AI = Ollama()

# ─────────────────────────────────────────────────────────────────
# PROJECT KNOWLEDGE BASE
# ─────────────────────────────────────────────────────────────────

def load_schema() -> str:
    return SCHEMA.read_text(encoding="utf-8", errors="replace") if SCHEMA.exists() else ""

def schema_models() -> dict:
    """Return {ModelName: [fieldName, ...]}"""
    models, cur = {}, None
    for line in load_schema().splitlines():
        m = re.match(r'^model\s+(\w+)\s*\{', line)
        if m:
            cur = m.group(1); models[cur] = []
        elif cur:
            fm = re.match(r'^\s+(\w+)\s+\S', line)
            if fm and fm.group(1) not in ("@@", "@"):
                models[cur].append(fm.group(1))
            if line.strip() == "}":
                cur = None
    return models

def all_source_files() -> list:
    """Return all .js and .dart source files in backend/src and frontend/lib."""
    files = []
    for root, exts in [(BACKEND / "src", ["*.js"]), (FRONTEND / "lib", ["*.dart"])]:
        if root.exists():
            for ext in exts:
                files.extend(root.rglob(ext))
    return files

def read_file(path) -> str | None:
    p = pathlib.Path(path)
    return p.read_text(encoding="utf-8", errors="replace") if p.exists() else None

def write_file(path, content: str):
    p = pathlib.Path(path)
    p.write_text(content, encoding="utf-8")

def backup(path: pathlib.Path):
    bak = path.with_suffix(path.suffix + ".bak")
    shutil.copy2(path, bak)

def restore(path: pathlib.Path):
    bak = path.with_suffix(path.suffix + ".bak")
    if bak.exists():
        shutil.copy2(bak, path)
        log(f"Restored {path.name} from backup", "RESTORE")

# ─────────────────────────────────────────────────────────────────
# PROMPT HANDLING
# ─────────────────────────────────────────────────────────────────

_NOISE = ("NEW CAPABILITY", "NOTE:", "- code_fixer", "# auto", "OLLAMA", "---", "Write your issue")

def load_prompt() -> str:
    if not PROMPT_FILE.exists():
        return ""
    lines, clean = PROMPT_FILE.read_text(encoding="utf-8", errors="replace").splitlines(), []
    for line in lines:
        if any(line.strip().startswith(n) for n in _NOISE):
            break
        clean.append(line)
    text = "\n".join(clean).strip()
    return "" if not text else text

def clear_prompt():
    PROMPT_FILE.write_text(
        "Write your prompt here.\n\n"
        "Examples:\n"
        "  pramukh login is not working\n"
        "  society list — add status toggle button and reset password button\n"
        "  500 on GET /api/plans — unknown field registrationNo\n"
        "  add dark mode toggle to settings screen\n",
        encoding="utf-8",
    )
    log("Prompt file reset", "DONE")

# ─────────────────────────────────────────────────────────────────
# STEP 1 — UNDERSTAND INTENT
# ─────────────────────────────────────────────────────────────────

def understand_intent(prompt: str) -> dict:
    """
    Ask Ollama to classify the prompt and produce a structured plan.
    Returns a dict with: intent, layers, tasks, keywords
    intent: "bug_fix" | "feature" | "enhancement" | "refactor"
    layers: list of "db" | "backend" | "frontend"
    tasks:  list of plain-English task descriptions
    keywords: list of domain words (used for file discovery)
    """
    schema_summary = "\n".join(
        f"  {name}: {', '.join(fields[:6])}"
        for name, fields in list(schema_models().items())[:20]
    )

    plan_prompt = f"""Society Manager SaaS (Node/Express/Prisma backend, Flutter/Riverpod frontend).
Models: {schema_summary}

Request: "{prompt}"

Reply with JSON only, no markdown:
{{"intent":"bug_fix|feature|enhancement","summary":"one line","layers":["backend","frontend"],"tasks":["task1","task2"],"keywords":["word1","word2"]}}"""

    result = AI.ask_json(plan_prompt, max_tokens=400)
    if not result or not isinstance(result, dict):
        # Fallback: basic keyword extraction
        words = set(re.findall(r'\b[a-zA-Z]{3,}\b', prompt.lower()))
        return {
            "intent":   "bug_fix",
            "summary":  prompt,
            "layers":   ["backend", "frontend"],
            "tasks":    [prompt],
            "keywords": list(words)[:10],
        }

    log(f"Intent: {result.get('intent')} — {result.get('summary')}", "PLAN")
    for t in result.get("tasks", []):
        log(f"  • {t}", "PLAN")
    return result

# ─────────────────────────────────────────────────────────────────
# STEP 2 — DISCOVER ALL LINKED FILES
# ─────────────────────────────────────────────────────────────────

# Feature → folder mappings (covers both backend modules and flutter features)
FEATURE_MAP = {
    "auth":         ["auth"],
    "login":        ["auth"],
    "logout":       ["auth"],
    "register":     ["auth"],
    "password":     ["auth", "users"],
    "jwt":          ["auth", "utils"],
    "token":        ["auth", "utils"],
    "role":         ["auth", "middleware"],
    "permission":   ["middleware"],
    "society":      ["societies", "society", "superadmin"],
    "societies":    ["societies", "superadmin"],
    "plan":         ["plans"],
    "plans":        ["plans"],
    "subscription": ["subscriptions"],
    "unit":         ["units"],
    "units":        ["units"],
    "user":         ["users"],
    "users":        ["users"],
    "resident":     ["users", "units"],
    "pramukh":      ["auth", "users", "dashboard"],
    "secretary":    ["auth", "users"],
    "watchman":     ["auth", "visitors"],
    "bill":         ["bills"],
    "bills":        ["bills"],
    "maintenance":  ["bills"],
    "payment":      ["bills", "subscriptions"],
    "expense":      ["expenses"],
    "expenses":     ["expenses"],
    "visitor":      ["visitors"],
    "visitors":     ["visitors"],
    "complaint":    ["complaints"],
    "complaints":   ["complaints"],
    "staff":        ["staff"],
    "notice":       ["notices"],
    "notices":      ["notices"],
    "notification": ["notifications"],
    "notifications":["notifications"],
    "amenity":      ["amenities"],
    "amenities":    ["amenities"],
    "booking":      ["amenities"],
    "gatepass":     ["gatepasses"],
    "gate":         ["gatepasses"],
    "delivery":     ["deliveries"],
    "vehicle":      ["vehicles"],
    "domestic":     ["domestic"],
    "dashboard":    ["dashboard", "superadmin"],
    "superadmin":   ["superadmin"],
    "setting":      ["settings"],
    "settings":     ["settings"],
    "profile":      ["profile", "users"],
    "report":       ["reports"],
    "analytics":    ["dashboard", "reports"],
    "dark":         ["theme", "settings"],
    "theme":        ["theme", "core"],
    "color":        ["theme", "core"],
    "status":       ["societies", "units"],
    "toggle":       ["societies", "units"],
    "prisma":       [],
    "schema":       [],
    "migration":    [],
    "database":     [],
    "db":           [],
}

_STOP = {
    "the","and","for","that","this","with","from","have","been","not","are",
    "but","can","will","fix","issue","error","when","then","make","please",
    "working","works","page","get","post","put","patch","delete","http","json",
    "null","true","false","return","using","used","does","show","display",
    "always","never","after","before","while","still","just","only","dont",
    "cannot","could","would","might","must","may","also","its","via","same",
    "way","like","want","need","should","dont","into","onto","upon","about",
}

def _extract_keywords(text: str, extra: list = None) -> set:
    words = set(re.findall(r'\b[a-zA-Z_]\w{2,}\b', text.lower()))
    result = (words - _STOP)
    if extra:
        result |= {w.lower() for w in extra if len(w) > 2}
    return result

def discover_files(prompt: str, plan: dict) -> list:
    """
    Score every source file by relevance to the prompt + plan.
    Returns list of (score, Path) sorted descending.

    Scoring:
      +5  file path contains a FEATURE_MAP folder for a keyword
      +3  file stem contains a keyword directly
      +2  file path contains a keyword
      +1  per keyword occurrence in file content (capped at 8 per keyword)
      +3  file stem matches a prisma model name from plan keywords
    """
    keywords = _extract_keywords(prompt, plan.get("keywords", []))
    models   = {k.lower() for k in schema_models()}

    score_map = {}

    for f in all_source_files():
        path_l = str(f).lower().replace("\\", "/")
        stem_l = f.stem.lower().replace("_", "").replace("-", "")
        score  = 0

        # Feature folder boost
        for kw in keywords:
            for folder in FEATURE_MAP.get(kw, []):
                if f"/{folder}/" in path_l or path_l.endswith(f"/{folder}"):
                    score += 5

        # Filename match
        for kw in keywords:
            kw_c = kw.replace("_", "").replace("-", "")
            if kw_c in stem_l:
                score += 3
            elif kw in path_l:
                score += 2

        # Model name match
        for kw in keywords:
            if kw in models:
                model_stem = kw.replace("_", "")
                if model_stem in stem_l:
                    score += 3

        # Content scan
        if score > 0:
            try:
                content = f.read_text(encoding="utf-8", errors="replace")
                for kw in keywords:
                    hits = min(content.lower().count(kw), 8)
                    score += hits
            except Exception:
                pass

        if score > 0:
            score_map[f] = score

    ranked = sorted(score_map.items(), key=lambda x: -x[1])
    seen, result = set(), []
    for f, sc in ranked:
        key = str(f)
        if key not in seen:
            seen.add(key)
            result.append((sc, f))
        if len(result) >= 25:
            break
    return result

def triage_files(prompt: str, plan: dict, candidates: list) -> list:
    """
    Ask Ollama to pick which files actually need to change.
    Returns list of Path objects.
    """
    if not candidates:
        return []

    # Keep only top-12 by score, one line each (path only — no previews to save tokens)
    entries = "\n".join(
        f"  {i+1}. {f.relative_to(BASE)}"
        for i, (sc, f) in enumerate(candidates[:12])
    )

    q = f"""Request: "{prompt}"
Tasks: {"; ".join(plan.get("tasks", [prompt])[:4])}

Files:
{entries}

Which file numbers need changes? Reply with JSON array only, e.g. [1,3,5]. Max 8."""

    result = AI.ask_json(q, max_tokens=64)
    picked = []

    if isinstance(result, list):
        for idx in result:
            if isinstance(idx, int) and 0 <= idx <= len(candidates):
                if idx == 0:
                    picked.append(SCHEMA)
                else:
                    picked.append(candidates[idx - 1][1])

    if not picked:
        # Fallback: top 5 by score
        picked = [f for _, f in candidates[:5]]

    return picked

# ─────────────────────────────────────────────────────────────────
# STEP 3 — IMPLEMENT (diagnose + write)
# ─────────────────────────────────────────────────────────────────

PROJECT_CONTEXT = """Project: Society Manager SaaS
Backend : Node.js 20, Express 5, Prisma, PostgreSQL
Frontend: Flutter 3, Riverpod, GoRouter, Dio
Rules   : society_id on every query, AppColors/AppTextStyles only (no raw hex), JWT uppercase roles"""

def _lang(f: pathlib.Path) -> str:
    return {
        ".js":    "JS/Node/Prisma",
        ".dart":  "Dart/Flutter",
        ".prisma":"Prisma Schema",
        ".yaml":  "YAML",
    }.get(f.suffix, "code")

def _smart_excerpt(content: str, keywords: list, max_chars: int = 3000) -> str:
    """
    If file is large, return only the most relevant section around keyword hits
    rather than truncating from the top. Keeps imports + relevant block.
    """
    if len(content) <= max_chars:
        return content

    lines = content.splitlines()
    kw_lower = [k.lower() for k in keywords]

    # Score each line by keyword hits
    scored = []
    for i, line in enumerate(lines):
        ll = line.lower()
        hits = sum(1 for k in kw_lower if k in ll)
        if hits:
            scored.append((hits, i))

    if not scored:
        # No keyword hits — return start + end
        half = max_chars // 2
        return content[:half] + "\n\n... [truncated] ...\n\n" + content[-half:]

    # Sort by score, take top hit, expand context ±60 lines
    scored.sort(key=lambda x: -x[0])
    center = scored[0][1]
    start  = max(0, center - 60)
    end    = min(len(lines), center + 60)

    # Always include imports (first ~15 lines)
    imports = lines[:15]
    snippet = lines[start:end]

    result = "\n".join(imports) + "\n\n// ... [relevant section] ...\n\n" + "\n".join(snippet)
    return result[:max_chars]

def implement_file(prompt: str, plan: dict, filepath: pathlib.Path, schema: str) -> bool:
    """
    Two-step agent loop for one file:
      A) Diagnose what needs to change (short prompt, small output)
      B) Implement — send full file, get back full fixed file
    Returns True if the file was changed.
    """
    content = read_file(filepath)
    if content is None:
        log(f"File not found: {filepath}", "WARN")
        return False

    lang     = _lang(filepath)
    rel      = filepath.relative_to(BASE)
    keywords = plan.get("keywords", []) + list(_extract_keywords(prompt))
    excerpt  = _smart_excerpt(content, keywords, max_chars=2500)
    schema_block = (
        f"\nSchema (relevant models):\n```\n{schema[:1500]}\n```"
        if filepath.suffix == ".js" and schema else ""
    )

    # ── A: Diagnose (tiny prompt, tiny output) ────────────────────
    diag_prompt = (
        f'File: {rel} ({lang})\n'
        f'Request: "{prompt}"\n'
        f'Tasks: {"; ".join(plan.get("tasks",[prompt])[:3])}\n\n'
        f'```\n{excerpt}\n```\n'
        f'{schema_block}\n\n'
        f'List bullet points of what to change in THIS file. '
        f'If nothing needs changing, reply: NO CHANGES NEEDED'
    )

    diagnosis = AI.ask(diag_prompt, max_tokens=300)
    if not diagnosis:
        log(f"  {rel.name}: Ollama unavailable", "SKIP")
        return False

    if "NO CHANGES NEEDED" in diagnosis.upper():
        log(f"  {rel.name}: no changes needed", "SKIP")
        return False

    log(f"  {rel.name} — changes:", "PLAN")
    for line in diagnosis.splitlines()[:5]:
        if line.strip():
            log(f"    {line.strip()}")

    # ── B: Implement ─────────────────────────────────────────────
    # Use smart excerpt for large files to keep prompt short enough
    # for slow local models (4 tok/s on 14b means every 4KB costs ~4min)
    MAX_IMPL_CHARS = 4000   # ~1000 tokens input — keeps timeout under 10min
    impl_content   = _smart_excerpt(content, keywords, max_chars=MAX_IMPL_CHARS)
    is_truncated   = len(content) > MAX_IMPL_CHARS

    trunc_note = (
        "\nNOTE: File was truncated. Return ONLY the changed section wrapped in the full file structure."
        if is_truncated else ""
    )

    impl_prompt = (
        f'You are an expert {lang} developer.\n'
        f'Request: "{prompt}"\n'
        f'Changes needed:\n{diagnosis}\n\n'
        f'File: {rel}{trunc_note}\n'
        f'```{filepath.suffix.lstrip(".")}\n{impl_content}\n```\n'
        f'{schema_block}\n\n'
        f'Rules: Flutter=AppColors.*/AppTextStyles.*, Backend=keep society_id, preserve existing code.\n'
        f'Return ONLY the complete updated file in one ```code``` block:'
    )

    response = AI.ask(impl_prompt, max_tokens=4096)
    if not response:
        log(f"  {rel.name}: no response from Ollama", "FAIL")
        return False

    # Extract code block
    m = re.search(r"```(?:\w+)?\n([\s\S]+?)\n```", response)
    new_code = (m.group(1) if m else response).strip()

    # Sanity checks
    if len(new_code) < 40:
        log(f"  {rel.name}: response too short ({len(new_code)} chars)", "FAIL")
        return False
    code_signals = ("import", "require", "class ", "function ", "def ", "=>",
                    "model ", "widget", "provider", "const ", "return ")
    if not any(sig in new_code for sig in code_signals):
        log(f"  {rel.name}: response doesn't look like code", "FAIL")
        return False
    if len(new_code) < len(content) * 0.3:
        log(f"  {rel.name}: response suspiciously short vs original — skipping", "FAIL")
        return False

    # Backup + write
    backup(filepath)
    write_file(filepath, new_code)
    log(f"  {rel.name}: written ✓  ({len(content)} → {len(new_code)} chars)", "WRITE")
    return True

# ─────────────────────────────────────────────────────────────────
# STEP 4 — VERIFY
# ─────────────────────────────────────────────────────────────────

def verify_js(files: list) -> list:
    """Syntax-check JS files. Restore from backup if broken. Returns broken list."""
    broken = []
    for f in files:
        _, err, rc = run(f'node --check "{f}"')
        if rc == 0:
            log(f"  ✓ {f.name}", "JS")
        else:
            log(f"  ✗ {f.name} — {err.strip()[:120]}", "JS")
            restore(f)
            broken.append(f)
    return broken

def verify_prisma() -> bool:
    _, err, rc = run("npx prisma validate", cwd=BACKEND)
    if rc == 0:
        log("Prisma schema valid", "OK")
        return True
    log(f"Prisma schema invalid: {err[:300]}", "ERROR")
    return False

def verify_flutter() -> list:
    """Run flutter analyze. Returns list of error strings."""
    out, err, _ = run("flutter analyze", cwd=FRONTEND)
    pat = re.compile(r"^\s+(error|warning)\s+-\s+(.+?)\s+-\s+(.+?):(\d+):\d+", re.MULTILINE)
    issues = []
    for m in pat.finditer(out + err):
        issues.append(f"{m.group(1).upper()} {m.group(2)} — {m.group(3)}:{m.group(4)}")
    return issues

def regenerate_prisma():
    kill_port(3000)
    _, err, rc = run("npx prisma generate", cwd=BACKEND)
    if rc == 0:
        log("Prisma client regenerated", "OK")
    elif "EPERM" in err:
        time.sleep(3)
        _, err2, rc2 = run("npx prisma generate", cwd=BACKEND)
        log("Prisma client regenerated (retry)" if rc2 == 0 else f"Prisma generate failed: {err2[:150]}", "OK" if rc2 == 0 else "WARN")

# ─────────────────────────────────────────────────────────────────
# PORT / PM2 HELPERS
# ─────────────────────────────────────────────────────────────────

def kill_port(port: int):
    try:
        pm2 = subprocess.run("npx pm2 list --no-color", shell=True,
                             capture_output=True, encoding="utf-8", errors="replace")
        if "online" in (pm2.stdout or ""):
            subprocess.run("npx pm2 stop all", shell=True, capture_output=True)
            log(f"PM2 stopped (freeing port {port})", "PM2")
            time.sleep(1)
    except Exception:
        pass

    try:
        out = subprocess.run("netstat -ano", shell=True, capture_output=True,
                             encoding="utf-8", errors="replace").stdout or ""
        for line in out.splitlines():
            if f":{port} " in line and "LISTENING" in line:
                pid = line.split()[-1]
                if pid.isdigit():
                    subprocess.run(
                        f'powershell -Command "Stop-Process -Id {pid} -Force -ErrorAction SilentlyContinue"',
                        shell=True, capture_output=True,
                    )
                    log(f"Killed PID {pid} on port {port}", "PM2")
    except Exception:
        pass

def pm2_restart():
    try:
        pm2 = subprocess.run("npx pm2 list --no-color", shell=True,
                             capture_output=True, encoding="utf-8", errors="replace")
        if "stopped" in (pm2.stdout or "") or "online" in (pm2.stdout or ""):
            subprocess.run("npx pm2 restart all", shell=True, capture_output=True)
            log("PM2 restarted — new code is live", "PM2")
    except Exception:
        pass

# ─────────────────────────────────────────────────────────────────
# MAINTENANCE PASS (no prompt)
# ─────────────────────────────────────────────────────────────────

def flutter_issues(cwd):
    out, err, _ = run("flutter analyze", cwd=cwd)
    issues = []
    pat = re.compile(r"^\s+(error|warning|info)\s+-\s+(.+?)\s+-\s+(.+?):(\d+):\d+\s+-\s+(\S+)$")
    for line in (out + err).splitlines():
        m = pat.match(line)
        if m:
            issues.append({"severity": m.group(1), "message": m.group(2),
                           "file": m.group(3).replace("\\", "/"),
                           "line": int(m.group(4)), "code": m.group(5)})
    return issues

def remove_import_line(content, pkg):
    return "".join(l for l in content.splitlines(keepends=True)
                   if pkg not in l or not l.strip().startswith("import"))

def fix_unused_import(filepath, pkg):
    content = read_file(filepath)
    if not content: return
    new = remove_import_line(content, pkg)
    if new != content:
        write_file(filepath, new)
        log(f"Removed unused import '{pkg}' from {filepath}", "FIX")

def maintenance_pass():
    header("Maintenance Pass")

    # 1. Prisma
    section("Prisma")
    kill_port(3000)
    run("npx prisma format", cwd=BACKEND)
    if verify_prisma():
        regenerate_prisma()

    # 2. Bad model references
    section("Model Reference Check")
    real_models = {
        (n[0].lower() + n[1:]) for n in schema_models()
    }
    skip_methods = {"$connect","$disconnect","$transaction","$queryRaw","$executeRaw","$use","$on"}
    problems = {}
    for f in (BACKEND / "src").rglob("*.js") if (BACKEND/"src").exists() else []:
        content = f.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r'\bprisma\.(\w+)\b', content):
            ref = m.group(1)
            if ref in skip_methods or ref in real_models:
                continue
            problems.setdefault(str(f.relative_to(BASE)), set()).add(ref)
    if problems:
        log("Bad prisma model references:", "WARN")
        for fp, refs in problems.items():
            log(f"  {fp} → {', '.join(refs)}", "WARN")
    else:
        log("All prisma references valid", "OK")

    # 3. JWT role
    section("JWT Role Check")
    auth_ctrl = BACKEND / "src" / "modules" / "auth" / "auth.controller.js"
    content = read_file(str(auth_ctrl))
    if content and "role:" in content and ".toLowerCase()" in content:
        in_payload = False
        lines, new_lines = content.splitlines(keepends=True), []
        changed = False
        for line in lines:
            if re.search(r'\bpayload\s*=\s*\{', line): in_payload = True
            if in_payload and 'role:' in line and '.toLowerCase()' in line:
                fixed = re.sub(r'(role:\s*\S+?)\.toLowerCase\(\)', r'\1', line)
                if fixed != line:
                    new_lines.append(fixed); changed = True
                    log("JWT payload role: removed .toLowerCase()", "FIX")
                    continue
            if in_payload and '};' in line: in_payload = False
            new_lines.append(line)
        if changed:
            write_file(str(auth_ctrl), "".join(new_lines))

    # 4. Flutter
    section("Flutter")
    issues = flutter_issues(FRONTEND)
    errors   = [i for i in issues if i["severity"] == "error"]
    warnings = [i for i in issues if i["severity"] == "warning"]
    log(f"Found {len(errors)} errors, {len(warnings)} warnings")

    for issue in errors:
        fp = FRONTEND / issue["file"]
        code = issue["code"]
        log(f"  {code} — {issue['file']}:{issue['line']}", "ERROR")
        if code in ("uri_does_not_exist", "uri_has_not_been_generated"):
            m = re.search(r"'([^']+)'", issue["message"])
            if m: fix_unused_import(str(fp), m.group(1))
        elif code == "const_with_non_const":
            c = read_file(str(fp))
            if c:
                ls = c.splitlines(keepends=True)
                ln = issue["line"] - 1
                if ln < len(ls): ls[ln] = ls[ln].replace("const ", "", 1)
                write_file(str(fp), "".join(ls))
        else:
            AI.fix_file_one_shot(str(fp), issue["message"]) if hasattr(AI, "fix_file_one_shot") else None

    for issue in warnings:
        fp = FRONTEND / issue["file"]
        if issue["code"] == "unused_import":
            m = re.search(r"'([^']+)'", issue["message"])
            if m: fix_unused_import(str(fp), m.group(1))

    # Suppress known unfixable infos
    ao = FRONTEND / "analysis_options.yaml"
    content = read_file(str(ao)) or ""
    rules = ["use_null_aware_elements", "unnecessary_underscores"]
    changed = False
    if "linter:" not in content: content += "\nlinter:\n  rules:\n"
    for rule in rules:
        if rule not in content:
            content = re.sub(r"(linter:\n\s+rules:)", rf"\1\n    {rule}: false", content)
            changed = True
    if changed: write_file(str(ao), content)

    run("dart fix --apply", cwd=FRONTEND)
    run("flutter pub get", cwd=FRONTEND)
    log("Flutter pass complete", "OK")

    # 5. npm install
    run("npm install", cwd=BACKEND)
    log("npm install complete", "OK")

# ─────────────────────────────────────────────────────────────────
# SMOKE TEST
# ─────────────────────────────────────────────────────────────────

def smoke_test():
    import urllib.request, urllib.error
    BASE_URL = "http://localhost:3000/api"

    def api(method, path, body=None, token=None):
        url  = BASE_URL + path
        data = json.dumps(body).encode() if body else None
        req  = urllib.request.Request(url, data=data, method=method)
        req.add_header("Content-Type", "application/json")
        if token: req.add_header("Authorization", f"Bearer {token}")
        try:
            with urllib.request.urlopen(req, timeout=5) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            try:    return e.code, json.loads(e.read())
            except: return e.code, {}
        except Exception as ex:
            return None, str(ex)

    status, _ = api("GET", "/../health")
    if status is None:
        log("Backend not running — skipping smoke tests", "SKIP")
        return

    section("Smoke Tests")
    st, body = api("POST", "/auth/login", {"identifier": "9999999999", "password": "Admin@123"})
    if st != 200:
        log(f"Login failed: {st}", "FAIL"); return
    token = body.get("data", {}).get("accessToken")
    log(f"Login OK — role: {body.get('data',{}).get('user',{}).get('role')}", "OK")

    for method, path, label in [
        ("GET", "/superadmin/dashboard",       "SA dashboard"),
        ("GET", "/superadmin/societies/recent","SA societies"),
        ("GET", "/dashboard/stats",            "Society stats"),
    ]:
        st, _ = api(method, path, token=token)
        log(f"  {label} → {st}", "OK" if st == 200 else "FAIL")

# ─────────────────────────────────────────────────────────────────
# MAIN AGENT LOOP
# ─────────────────────────────────────────────────────────────────

def agent_loop(prompt: str):
    """Full agent pipeline: understand → discover → implement → verify → restart"""

    header("AGENT MODE")
    log(f"Prompt: {prompt}")

    schema = load_schema()

    # ── 1. Understand intent ──────────────────────────────────────
    section("Step 1 — Understanding Intent")
    plan = understand_intent(prompt)

    # ── 2. Discover files ─────────────────────────────────────────
    section("Step 2 — Discovering Files")
    candidates = discover_files(prompt, plan)
    log(f"Scored {len(candidates)} candidate file(s):")
    for sc, f in candidates[:15]:
        log(f"  [{sc:3d}] {f.relative_to(BASE)}")

    to_change = triage_files(prompt, plan, candidates)
    log(f"\nFiles selected for implementation ({len(to_change)}):")
    for f in to_change:
        log(f"  → {f.relative_to(BASE)}")

    # ── 3. Implement each file ────────────────────────────────────
    section("Step 3 — Implementing Changes")
    changed_files = []
    for filepath in to_change:
        log(f"\nProcessing: {filepath.relative_to(BASE)}")
        ok = implement_file(prompt, plan, filepath, schema)
        if ok:
            changed_files.append(filepath)

    if not changed_files:
        log("No files were changed by the agent.", "WARN")
        log("Possible reasons: Ollama unavailable, prompt too vague, or no matching code found.")
        return

    log(f"\nChanged {len(changed_files)} file(s):", "DONE")
    for f in changed_files:
        log(f"  ✓ {f.relative_to(BASE)}")

    # ── 4. Verify ─────────────────────────────────────────────────
    section("Step 4 — Verifying Changes")

    js_changed    = [f for f in changed_files if f.suffix == ".js"]
    dart_changed  = [f for f in changed_files if f.suffix == ".dart"]
    prisma_changed = any(f.name == "schema.prisma" for f in changed_files)

    broken_js = verify_js(js_changed)
    if broken_js:
        log(f"  {len(broken_js)} JS file(s) had syntax errors — restored from backup", "WARN")

    if prisma_changed or js_changed:
        if verify_prisma():
            regenerate_prisma()

    if dart_changed:
        flutter_errors = verify_flutter()
        if flutter_errors:
            log(f"  Flutter errors after change ({len(flutter_errors)}):", "WARN")
            for e in flutter_errors[:8]:
                log(f"    {e}")
        else:
            log("Flutter analyze — no errors", "OK")

    # ── 5. Restart ────────────────────────────────────────────────
    section("Step 5 — Restarting Server")
    pm2_restart()

    # ── 6. Summary ────────────────────────────────────────────────
    section("Summary")
    log(f"Intent   : {plan.get('intent')} — {plan.get('summary')}")
    log(f"Files    : {len(changed_files)} modified")
    for f in changed_files:
        log(f"  ✓ {f.relative_to(BASE)}")
    if broken_js:
        log(f"Reverted : {len(broken_js)} broken JS file(s)")
    log("Agent run complete.", "DONE")

# ─────────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────────

def main():
    LOG_FILE.write_text("", encoding="utf-8")

    print("╔" + "═" * 60 + "╗")
    print("║   SOCIETY MANAGER — AUTONOMOUS AI AGENT  v5.0" + " " * 13 + "║")
    print("╚" + "═" * 60 + "╝\n")

    prompt = load_prompt()

    if prompt:
        # ── AGENT MODE: understand + implement the prompt ──────────
        agent_loop(prompt)
        clear_prompt()
    else:
        # ── MAINTENANCE MODE: standard health checks ───────────────
        print("   No prompt — running maintenance pass.\n")
        maintenance_pass()

    smoke_test()

    print("\n" + "═" * 62)
    print(f"   Log: {LOG_FILE}")
    print("═" * 62)


if __name__ == "__main__":
    main()
