import sys
import pathlib
import re
import subprocess

def load_workflow(path: pathlib.Path) -> str:
    """Read a markdown workflow file and return its raw text."""
    return path.read_text(encoding="utf-8")

def extract_steps(content: str) -> list[str]:
    """Extract numbered steps from the markdown.
    Returns a list of step strings (without the leading number)."""
    steps = []
    for line in content.splitlines():
        m = re.match(r"^\d+\.\s+(.*)", line)
        if m:
            steps.append(m.group(1).strip())
    return steps

def main():
    if len(sys.argv) != 2:
        print("Usage: python run_workflow.py <workflow.md>")
        sys.exit(1)
    wf_path = pathlib.Path(sys.argv[1])
    if not wf_path.is_file():
        print(f"Workflow file not found: {wf_path}")
        sys.exit(1)
    content = load_workflow(wf_path)
    print("--- Workflow Description ---")
    # Print the YAML front‑matter description if present
    desc_match = re.search(r"---\s*description:\s*(.*)\s*---", content, re.IGNORECASE)
    if desc_match:
        print(desc_match.group(1).strip())
    else:
        print("(no description)\n")
    steps = extract_steps(content)
    if not steps:
        print("No numbered steps found in the workflow.")
        return
    print("\n--- Steps ---")
    for i, step in enumerate(steps, start=1):
        print(f"{i}. {step}")
    print("\nYou can now execute the steps manually or write a custom runner that calls the appropriate tools.")

if __name__ == "__main__":
    main()
