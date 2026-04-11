import os
import requests
import shutil

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = input("Model (qwen2.5:14b recommended): ").strip()
PROJECT_PATH = input("Project path: ").strip()

VALID_EXT = (".dart", ".js", ".ts", ".json", ".sql")

# ================= SMART PROMPTS =================

def get_prompt(file_path, code):
    if file_path.endswith(".dart"):
        return f"""
You are a senior Flutter developer.

Fix this Flutter code:
- Fix buttons (onPressed not working)
- Fix API calls (http/dio)
- Fix UI alignment and responsiveness
- Ensure state updates properly

Return full corrected code only.

CODE:
{code}
"""

    elif file_path.endswith(".js") or file_path.endswith(".ts"):
        return f"""
You are a senior Node.js backend engineer.

Fix this backend code:
- Fix API routes
- Fix controller logic
- Ensure CRUD works with PostgreSQL
- Fix async/await issues
- Ensure proper error handling

Return full corrected code only.

CODE:
{code}
"""

    elif file_path.endswith(".sql"):
        return f"""
You are a PostgreSQL expert.

Fix this SQL:
- Ensure proper schema
- Fix relations and constraints
- Optimize queries

Return full corrected SQL.

CODE:
{code}
"""

    else:
        return None


# ================= CORE =================

def call_ollama(prompt):
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": MODEL,
            "prompt": prompt,
            "stream": False,
            "options": {"temperature": 0.3}
        }
    )
    return response.json()["response"]


def backup(file):
    shutil.copy(file, file + ".bak")


def process_file(file_path):
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            code = f.read()

        prompt = get_prompt(file_path, code)
        if not prompt:
            return

        print(f"🔧 Fixing: {file_path}")

        backup(file_path)

        fixed = call_ollama(prompt)

        # Second pass improvement
        improved = call_ollama(f"""
Improve this code further.
Fix any missed bugs and ensure full working flow.

CODE:
{fixed}
""")

        with open(file_path, "w", encoding="utf-8") as f:
            f.write(improved)

        print("✅ Done")

    except Exception as e:
        print(f"❌ Error: {file_path} -> {e}")


def scan_project(path):
    for root, dirs, files in os.walk(path):
        if "node_modules" in root or ".git" in root:
            continue

        for file in files:
            if file.endswith(VALID_EXT):
                process_file(os.path.join(root, file))


# ================= MAIN =================

print("\n🚀 Fullstack AI Fixer Started")
scan_project(PROJECT_PATH)
print("\n🎉 Completed")