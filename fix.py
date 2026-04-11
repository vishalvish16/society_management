# ═══════════════════════════════════════════════════════════════
#  SOCIETY MANAGER — Prompt-Driven Code Fixer Launcher
#  ─────────────────────────────────────────────────────────────
#  HOW TO USE:
#    1. Write your issue/prompt in the 'prompt' file.
#    2. Run:  python fix.py
#  The fixer will read your prompt, analyse the described issue,
#  apply targeted fixes, then run the full auto-fix pass.
# ═══════════════════════════════════════════════════════════════

import os, sys, re, pathlib, subprocess, textwrap
from datetime import datetime

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BASE     = pathlib.Path("e:/Society_Managment")
LOG_FILE = BASE / "fixer.log"

# ── YOUR PROMPT ── (edit 'prompt' file, then run `python fix.py`) ──
prompt_file = BASE / "prompt"
if prompt_file.exists():
    PROMPT = prompt_file.read_text(encoding="utf-8").strip()
else:
    PROMPT = """
Write your issue here.

Examples:
  - "500 error on GET /api/plans — prisma.plan fields don't match schema"
  - "Flutter login screen shows wrong error message on bad password"
  - "JWT always returns 401 on protected routes after login"
  - "society.registrationNo causes PrismaClientValidationError"
"""
# ── END OF PROMPT ────────────────────────────────────────────────


# ─────────────────────────────────────────────────────────────────
# DO NOT EDIT BELOW THIS LINE
# ─────────────────────────────────────────────────────────────────

# ── Helpers ───────────────────────────────────────────────────────

def log(msg):
    ts   = datetime.now().strftime("[%H:%M:%S]")
    line = f"{ts} {msg}"
    print(line)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(line + "\n")

def banner(title):
    print("\n" + "═" * 62)
    print(f"  {title}")
    print("═" * 62)

# ── Prompt analyser ───────────────────────────────────────────────

class PromptAnalyser:
    """
    Reads the PROMPT string and decides which targeted fixes to run
    before handing off to the main code_fixer.py pass.
    """

    KEYWORDS = {
        "prisma": [
            "prismavalidation", "prismafield", "unknownfield",
            "registrationno", "isactive", "subscription", "prisma",
        ],
        "auth": ["401", "403", "jwt", "token", "unauthorized", "roleGuard", "login"],
        "flutter": ["flutter", "dart", "widget", "screen", "ui", "riverpod", "provider"],
        "backend": ["500", "api", "route", "express", "controller", "service", "backend"],
        "database": ["migrate", "migration", "seed", "database", "db", "schema"],
    }

    def __init__(self, prompt: str):
        self.prompt  = prompt
        self.lower   = prompt.lower()
        self.matched = set()
        self._analyse()

    def _analyse(self):
        for category, keywords in self.KEYWORDS.items():
            if any(kw in self.lower for kw in keywords):
                self.matched.add(category)

    def summary(self) -> str:
        if not self.matched:
            return "No specific category detected — running full fix pass."
        return "Detected categories: " + ", ".join(sorted(self.matched))

    def has(self, category: str) -> bool:
        return category in self.matched

# ── Targeted fixes ────────────────────────────────────────────────

def targeted_fixes(analyser: PromptAnalyser):
    """Run lightweight targeted fixes based on the prompt before the full pass."""
    BACKEND  = BASE / "backend"
    FRONTEND = BASE / "frontend"

    if analyser.has("prisma"):
        log("\n[TARGET] Prisma issue detected — checking schema vs service field mismatches...")
        out, err, rc = _run("npx prisma validate", BACKEND)
        if rc == 0:
            log("  [OK] Prisma schema valid")
        else:
            log(f"  [ERROR] Prisma schema invalid:\n{err[:400]}")

        # Re-generate client so field list is fresh
        log("  Regenerating Prisma client...")
        out, err, rc = _run("npx prisma generate", BACKEND)
        log("  [OK] Prisma client regenerated" if rc == 0 else f"  [WARN] {err[:200]}")

    if analyser.has("auth"):
        log("\n[TARGET] Auth/JWT issue detected — checking role case in auth.controller.js...")
        auth_ctrl = BACKEND / "src" / "modules" / "auth" / "auth.controller.js"
        if auth_ctrl.exists():
            content = auth_ctrl.read_text(encoding="utf-8", errors="replace")
            if "toLowerCase()" in content and "role:" in content:
                log("  [WARN] Found .toLowerCase() on role in auth controller — this breaks roleGuard.")
                log("         Run the full fixer (python fix.py) to auto-fix it.")
            else:
                log("  [OK] No role case issue found in auth.controller.js")
        else:
            log("  [SKIP] auth.controller.js not found")

    if analyser.has("flutter"):
        log("\n[TARGET] Flutter issue detected — running flutter analyze...")
        out, err, rc = _run("flutter analyze", FRONTEND)
        lines = (out + err).splitlines()
        errors = [l for l in lines if "error •" in l or " error -" in l]
        if errors:
            log(f"  Found {len(errors)} Flutter error(s):")
            for e in errors[:10]:
                log(f"    {e.strip()}")
        else:
            log("  [OK] No Flutter errors found")

    if analyser.has("database"):
        log("\n[TARGET] Database/migration issue detected — checking pending migrations...")
        out, err, rc = _run("npx prisma migrate status", BACKEND)
        log(out[:600] if out else err[:400])

def _run(cmd, cwd):
    r = subprocess.run(
        cmd, cwd=str(cwd), shell=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        encoding="utf-8", errors="replace"
    )
    return r.stdout, r.stderr, r.returncode

# ── Main ──────────────────────────────────────────────────────────

def main():
    prompt = PROMPT.strip()

    # Validate prompt was actually edited
    if not prompt or "Write your issue here" in prompt:
        print("\n⚠  Please edit the 'prompt' file before running.\n")
        print(textwrap.dedent("""\
            Example:
              - "500 error on GET /api/plans — unknown field registrationNo"
        """))
        # sys.exit(1) # Don't exit if we have something from file

    # Clear log
    LOG_FILE.write_text("", encoding="utf-8")

    banner("SOCIETY MANAGER — PROMPT-DRIVEN CODE FIXER")
    print(f"\n  Prompt:\n{textwrap.indent(prompt, '    ')}\n")

    analyser = PromptAnalyser(prompt)
    log(analyser.summary())

    # Step 1 — targeted fixes based on prompt keywords
    targeted_fixes(analyser)

    # Step 2 — run the full auto code_fixer pass
    banner("Running full code_fixer.py pass...")
    fixer_path = BASE / "code_fixer.py"
    rc = subprocess.call(
        [sys.executable, str(fixer_path)],
        cwd=str(BASE)
    )

    banner("Done")
    print(f"  Exit code : {rc}")
    print(f"  Full log  : {LOG_FILE}")
    if rc == 0:
        print("  Status    : ALL FIXES APPLIED SUCCESSFULLY")
    else:
        print("  Status    : Some issues may need manual review — check fixer.log")

if __name__ == "__main__":
    main()
