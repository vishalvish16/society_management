---
description: Setup Claude Code integration with Ollama (local model)
---

1. **Install Claude Code CLI**
   ```powershell
   npm i -g @anthropic/claude-code
   ```
2. **Pull a coding‑oriented model in Ollama** (e.g., qwen2.5‑coder)
   ```powershell
   ollama pull qwen2.5-coder
   ```
3. **Verify Ollama is running** (optional)
   ```powershell
   ollama serve   # starts the Ollama server if not already running
   ```
4. **Run Claude Code using the local model**
   ```powershell
   claude --model qwen2.5-coder
   ```
   This starts an interactive Claude‑compatible REPL that uses the locally‑pulled model.
5. **(Optional) Set up Anthropic API compatibility**
   - If you have an Anthropic API key and want Claude‑Code to forward requests to the cloud, set the environment variable:
     ```powershell
     $env:ANTHROPIC_API_KEY = "YOUR_API_KEY"
     ```
   - Then run Claude Code with the `--model claude-3-sonnet` flag (Ollama will proxy to the cloud).
6. **Test the integration**
   - In the REPL, type a simple prompt like `Write a Dart function that returns the sum of two numbers.`
   - Verify the response is generated correctly.

**Notes**
- Ollama version 0.20.0 supports Anthropic API compatibility out of the box.
- The local model (`qwen2.5-coder`) provides fast, offline coding assistance.
- Adjust the model name in step 2 if you prefer a different open‑weight model (e.g., `llama3.2-coder`).
