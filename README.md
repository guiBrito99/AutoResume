# AutoResume: Local Match & Resume Pipeline

An automated, privacy-first pipeline that analyzes your career history against a target job description and produces both a match report and an HTML resume—all completely offline.

Instead of manually rewriting your resume for every application, this project acts as a "reverse Applicant Tracking System." It pulls your master career history from a local SQLite database, cross-references it with a target job description, uses your opencode setup to generate a JSON match report, and then renders a polished HTML resume from that report—no cloud, no tracking.

## ✨ Features

* **100% Local & Private:** No personal data is sent to cloud APIs. The entire pipeline runs securely on your machine through opencode's local server.
* **Database-Driven History:** Uses [java-sqlite-manager](https://github.com/guiBrito99/java-sqlite-manager) to cleanly store, manage, and retrieve your master list of skills, experiences, and projects.
* **Automated Orchestration:** A smart Bash script creates job-specific directories, extracts database records, and handles all LLM communication.
* **Match Report First:** The LLM produces a strict JSON report (`matches.txt`) with exactly three categories—Experience, Education, Skills—listing only requirements that have literal evidence in your data.
* **HTML Resume Builder:** A single-file Java component (`JavaResumeBuilder.java`) reads the match report and your profile to render a self-contained, print-ready HTML resume with adaptive layout.

## 🛠️ How It Works

1. **The Database:** Your entire career history (roles, tech stack, highlights) is stored via the `java-sqlite-manager` CLI.
2. **The Context:** You provide a target **Job Description** (pasted or from a master file). No structure rules or persona files are needed.
3. **The Match Step:** `generatePipeline.sh` extracts your personal data, calls the opencode server with a prompt that demands a JSON match report, validates the JSON, and writes `matches.txt`.
4. **The Build Step:** The same script immediately runs `JavaResumeBuilder.java` on `matches.txt` to produce `resume.html`—header from your profile, one section per non-empty category, adaptive grid layout when items exceed a threshold.

## 📦 Prerequisites

* **[opencode](https://opencode.ai/docs/)** installed and logged in to at least one provider (`opencode auth login`, or a provider configured in `opencode.json`).
* **Java JDK** (to run the `sqlite-manager-complete.jar` and to execute `JavaResumeBuilder.java` in source mode).
* **jq** (for secure JSON parsing and payload construction).
* **curl** (for the HTTP calls to the opencode server).
* A Linux environment or WSL (for the Bash script).

The opencode server is started automatically if one isn't already reachable at `http://localhost:4096`. Override with the `OPENCODE_URL` and `OPENCODE_PORT` environment variables.

### Using local Ollama models

The bundled `opencode.json` registers Ollama as a provider (`http://localhost:11434/v1`), so models you pull locally show up in the model picker. Add a new model pulled with `ollama pull <model>:<tag>` to the `models` map in `opencode.json`.

## 🚀 Quick Start

1. Ensure your `sqlite-manager-complete.jar` and the `scripts/` folder are in the same root directory.
2. Optionally, create a master `personalData.txt` file in the root directory to skip manual entry.
3. Make the scripts executable: `chmod +x run.sh scripts/installDependencies.sh`
4. Install dependencies: `./run.sh` (choose option 1 to install jq, curl, JDK, opencode, and optionally Ollama).
5. Run the pipeline: `./run.sh` (choose option 2 to generate a resume).

## ✅ Verification

Run the self-contained end-to-end test (starts an opencode server, feeds sample data, and asserts the output):

```bash
bash testScript.sh
```

The test script lives on the `dev` branch. On `main`, this test is not available since it is a dev-only artifact.

The test asserts:
- `test/matches.txt` exists and is valid JSON with `profile`, `labels`, `experience`, `education`, `skills`
- `test/resume.html` is generated, contains the candidate name, and renders the non-empty sections

## 🔧 Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `OPENCODE_URL` | `http://localhost:4096` | Base URL of the opencode server |
| `OPENCODE_PORT` | `4096` | Port used when starting a local server |
| `OPENCODE_START_TIMEOUT` | `60` | Seconds to wait for the server to come up |

## 📂 Output Artifacts

Per-job folder (named after the job title with spaces → underscores):

```
<Job_Title>/
├── personalData.txt    # Career history (extracted from DB or copied from root master)
├── jobDescription.txt  # Target job posting (user-provided)
├── matches.txt         # JSON match report (profile + labels + 3 categories)
└── resume.html         # Self-contained HTML resume
```