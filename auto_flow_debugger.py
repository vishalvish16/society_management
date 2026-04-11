import os
import requests
import shutil

OLLAMA_URL = "http://localhost:11434/api/generate"

MODEL = input("Enter model (qwen2.5:14b): ").strip()
PROJECT_PATH = input("Enter project path: ").strip()
AI_BRAIN_PATH = input("Enter AI brain json path: ").strip()

VALID_EXT = (".dart", ".js", ".ts", ".sql")

# ================= LOAD AI BRAIN =================
with open(AI_BRAIN_PATH, "r", encoding="utf-8") as f:
    AI_BRAIN = f.read()


# ================= OLLAMA =================
def call_ollama(prompt):
    try:
        res = requests.post(
            OLLAMA_URL,
            json={
                "model": MODEL,
                "prompt": prompt,
                "stream": False,
                "options": {
                    "temperature": 0.2
                }
            },
            timeout=300
        )
        return res.json()["response"]
    except Exception as e:
        print("❌ Ollama error:", e)
        return None


# ================= FILE SYSTEM =================
def scan_project():
    files = []
    for root, dirs, filenames in os.walk(PROJECT_PATH):
        if "node_modules" in root or ".git" in root:
            continue
        for f in filenames:
            if f.endswith(VALID_EXT):
                files.append(os.path.join(root, f))
    return files


def read_file(path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read()
    except:
        return ""


def backup(file):
    shutil.copy(file, file + ".bak")


# ================= FEATURE DETECTOR =================
def detect_feature_group(files):
    groups = {
        "visitor_flow": [],
        "billing_flow": [],
        "auth_flow": [],
        "general": []
    }

    for f in files:
        name = f.lower()
        if "visitor" in name or "qr" in name:
            groups["visitor_flow"].append(f)
        elif "bill" in name or "payment" in name:
            groups["billing_flow"].append(f)
        elif "auth" in name or "login" in name:
            groups["auth_flow"].append(f)
        else:
            groups["general"].append(f)

    return groups


# ================= FLOW DEBUG PROMPT =================
def build_flow_prompt(feature, files):
    combined_code = ""

    for f in files:
        code = read_file(f)
        combined_code += f"\nFILE: {f}\n{code[:1500]}\n"

    return f"""
You are an AI CTO and Flow Debugger.

================= SYSTEM =================
{AI_BRAIN}

================= FEATURE FLOW =================
{feature}

================= CODE =================
{combined_code}

================= TASK =================
Fix COMPLETE FLOW:

1. UI Layer (Flutter)
- Buttons must trigger actions
- UI must be responsive
- Fix layout issues

2. API Layer (Node.js)
- Fix endpoints
- Fix validation
- Ensure proper responses

3. DATABASE (PostgreSQL)
- Fix queries
- MUST include society_id
- Fix insert/update/delete

4. FLOW INTEGRATION
UI → API → DB → Response → UI Update must work

================= RULES =================
- Return FULL FIXED CODE for ALL FILES
- No explanation
- No TODO
- Production-ready code
"""


# ================= APPLY FIX =================
def apply_fix(files, ai_output):
    # Simple split strategy (can improve later)
    chunks = ai_output.split("FILE:")

    for chunk in chunks:
        if len(chunk.strip()) < 20:
            continue

        try:
            lines = chunk.strip().split("\n")
            file_path = lines[0].strip()

            if not os.path.exists(file_path):
                continue

            new_code = "\n".join(lines[1:])

            backup(file_path)

            with open(file_path, "w", encoding="utf-8") as f:
                f.write(new_code)

            print(f"✅ Fixed: {file_path}")

        except Exception as e:
            print("❌ Apply error:", e)


# ================= MAIN =================
def main():
    print("\n🚀 AUTO FLOW DEBUGGER STARTED")

    files = scan_project()
    print(f"📂 Total files: {len(files)}")

    groups = detect_feature_group(files)

    for feature, group_files in groups.items():
        if not group_files:
            continue

        print(f"\n🔍 Fixing Feature: {feature}")

        prompt = build_flow_prompt(feature, group_files)
        output = call_ollama(prompt)

        if output:
            apply_fix(group_files, output)

    print("\n🎉 ALL FLOWS FIXED")


if __name__ == "__main__":
    main()