import os
import time
import requests
import shutil

# ================= CONFIG =================
OLLAMA_URL = "http://localhost:11434/api/generate"

MODEL = input("Model (recommended: qwen2.5:7b): ").strip()
PROJECT_PATH = input("Project path: ").strip()
AI_BRAIN_PATH = input("AI brain path: ").strip()

VALID_EXT = (".dart", ".js", ".ts", ".sql")

MAX_FILES = 3
MAX_CHARS = 800
TIMEOUT = 900


# ================= LOAD AI BRAIN =================
with open(AI_BRAIN_PATH, "r", encoding="utf-8") as f:
    AI_BRAIN = f.read()


# ================= OLLAMA (STREAMING + RETRY) =================
def call_ollama(prompt, retries=2):
    for attempt in range(retries):
        try:
            res = requests.post(
                OLLAMA_URL,
                json={
                    "model": MODEL,
                    "prompt": prompt,
                    "stream": True,
                    "options": {"temperature": 0.2}
                },
                stream=True,
                timeout=TIMEOUT
            )

            output = ""

            for line in res.iter_lines():
                if line:
                    try:
                        chunk = line.decode("utf-8")
                        data = eval(chunk)
                        output += data.get("response", "")
                    except:
                        pass

            return output

        except Exception as e:
            print(f"❌ Retry {attempt+1}:", e)
            time.sleep(5)

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


# ================= FEATURE GROUP =================
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


# ================= PROMPT =================
def build_prompt(feature, files):
    combined_code = ""

    selected_files = files[:MAX_FILES]

    for f in selected_files:
        code = read_file(f)
        combined_code += f"\nFILE: {f}\n{code[:MAX_CHARS]}\n"

    return f"""
You are a senior AI CTO.

SYSTEM:
{AI_BRAIN}

FEATURE:
{feature}

CODE:
{combined_code}

TASK:
Fix COMPLETE FLOW:

1. Fix UI (Flutter responsive)
2. Fix API logic (Node.js)
3. Fix DB queries (PostgreSQL with society_id)
4. Fix CRUD operations
5. Fix UI state updates

RULES:
- Return FULL updated code
- Format:
FILE: <same path>
<code>

- No explanation
"""


# ================= APPLY FIX =================
def apply_fix(ai_output):
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
    print("\n🚀 AUTO FLOW DEBUGGER PRO")

    files = scan_project()
    print(f"📂 Total files: {len(files)}")

    groups = detect_feature_group(files)

    for feature, group_files in groups.items():
        if not group_files:
            continue

        print(f"\n🔍 Fixing Feature: {feature}")

        prompt = build_prompt(feature, group_files)
        output = call_ollama(prompt)

        if output:
            apply_fix(output)
        else:
            print("⚠️ No response from AI")

    print("\n🎉 DONE")


if __name__ == "__main__":
    main()