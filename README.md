# AutoResume: Local ATS Pipeline

An automated, privacy-first pipeline that generates highly tailored, ATS-optimized resumes using local LLMs.

Instead of manually rewriting your resume for every application, this project acts as a "reverse Applicant Tracking System." It pulls your master career history from a local SQLite database, cross-references it with a target job description, and uses your opencode setup to generate a customized resume—all completely offline.

## ✨ Features

* **100% Local & Private:** No personal data is sent to cloud APIs. The entire pipeline runs securely on your machine through opencode's local server.
* **Database-Driven History:** Uses [java-sqlite-manager](https://github.com/guiBrito99/java-sqlite-manager) to cleanly store, manage, and retrieve your master list of skills, experiences, and projects.
* **Automated Orchestration:** A smart Bash script creates job-specific directories, detects master templates, extracts database records, and handles all LLM communication.
* **ATS-Optimized Output:** Instructs the local AI to act as a Senior ATS Specialist, ensuring the final output heavily aligns with the target job's keywords and your defined structure rules.

## 🛠️ How It Works

1. **The Database:** Your entire career history (roles, tech stack, highlights) is stored via the `java-sqlite-manager` CLI.
2. **The Context:** You provide a target **Job Description** and your preferred **Structure Rules** (either as master `.txt` files in the root folder or pasted directly into the terminal).
3. **The Script:** `generateResume.sh` creates a dedicated folder for the specific job, extracts your personal data from the `.jar` application, and constructs a precise JSON payload.
4. **The LLM:** The script talks to the opencode server API (`opencode serve`), which runs your configured model and outputs a perfectly tailored `resume.txt` directly into the job folder.

## 📦 Prerequisites

* **[opencode](https://opencode.ai/docs/)** installed and logged in to at least one provider (`opencode auth login`, or a provider configured in `opencode.json`).
* **Java** (to run the `sqlite-manager-complete.jar`).
* **jq** (for secure JSON parsing and payload construction).
* **curl** (for the HTTP calls to the opencode server).
* A Linux environment or WSL (for the Bash script).

The opencode server is started automatically if one isn't already reachable at `http://localhost:4096`. Override with the `OPENCODE_URL` and `OPENCODE_PORT` environment variables.

### Using local Ollama models

The bundled `opencode.json` registers Ollama as a provider (`http://localhost:11434/v1`), so models you pull locally show up in the model picker. Add a new model pulled with `ollama pull <model>:<tag>` to the `models` map in `opencode.json`.

## 🚀 Quick Start

1. Ensure your `sqlite-manager-complete.jar` and `generateResume.sh` are in the same root directory.
2. Optionally, create master `personalData.txt` and `structureRules.txt` files in the root directory to skip manual entry.
3. Make the script executable: chmod +x generateResume.sh
4. Run the pipeline: ./generateResume.sh

## ✅ Verification

Run the self-contained end-to-end test (starts an opencode server, feeds sample data, and asserts the output):

```bash
bash testScript.sh
```

## 🔧 Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `OPENCODE_URL` | `http://localhost:4096` | Base URL of the opencode server |
| `OPENCODE_PORT` | `4096` | Port used when starting a local server |
| `OPENCODE_START_TIMEOUT` | `60` | Seconds to wait for the server to come up |