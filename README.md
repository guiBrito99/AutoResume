# AutoResume: Local Match & Resume Pipeline

An automated, privacy-first pipeline that analyzes your career history against a target job description and produces both a match report and an HTML resume—all completely offline.

Instead of manually rewriting your resume for every application, this project acts as a "reverse Applicant Tracking System." It pulls your master career history from a local SQLite database, cross-references it with a target job description, uses your opencode setup to generate a JSON match report, and then renders a polished HTML resume from that report—no cloud, no tracking.

## ✨ Features

* **100% Local & Private:** No personal data is sent to cloud APIs. The entire pipeline runs securely on your machine through opencode's local server.
* **Database-Driven History:** Uses [java-sqlite-manager](https://github.com/guiBrito99/java-sqlite-manager) to cleanly store, manage, and retrieve your master list of skills, experiences, and projects.
* **Automated Orchestration:** A smart Bash script creates job-specific directories, extracts database records, and handles all LLM communication.
* **Match Report First:** The LLM produces a strict JSON report (`matches.txt`) with exactly three categories—Experience, Education, Skills—listing only requirements that have literal evidence in your data.
* **HTML Resume Builder:** A Bash script (`scripts/foundation/resumeBuilder.sh`) renders the match report into a self-contained, print-ready HTML resume with adaptive layout. HTML escaping is delegated to `jq`'s `@html`, so there is no hand-rolled parser or escaping logic to get wrong.
* **Two Script Layers:** *foundation* scripts each do one job and never invoke another project script; *wrapper* scripts (the menu, the pipeline, the test harness) compose them.

## 🛠️ How It Works

The pipeline is split into small single-purpose scripts, orchestrated by `generateResume.sh`:

1. **The Database:** Your entire career history (roles, tech stack, highlights) is stored via the `java-sqlite-manager` CLI.
2. **Collect:** `collectJobDescription.sh` asks for the job title, creates the per-job folder, and saves the pasted **Job Description** to `jobDescription.txt`. No structure rules or persona files are needed.
3. **Match:** `infoMatcher.sh` extracts your personal data (from the database, or a master `personalData.txt`), calls the opencode server with a prompt that demands a JSON match report, validates the JSON, and writes `matches.txt`.
4. **Build:** `resumeBuilder.sh` runs on `matches.txt` to produce `resume.html`—header from your profile, one section per non-empty category, adaptive grid layout when items exceed a threshold.

Each step also runs standalone: `infoMatcher.sh` on its own gives you matches-only output, and `collectJobDescription.sh` only handles the description.

## 📦 Prerequisites

* **[opencode](https://opencode.ai/docs/)** installed and logged in to at least one provider (`opencode auth login`, or a provider configured in `opencode.json`).
* **Java** (a JRE is enough — only the `sqlite-manager-complete.jar` needs it now that the HTML builder is Bash).
* **jq** (for secure JSON parsing and payload construction).
* **curl** (for the HTTP calls to the opencode server).
* A Linux environment or WSL (for the Bash script).

The opencode server is started automatically if one isn't already reachable at `http://localhost:4096`. Override with the `OPENCODE_URL` and `OPENCODE_PORT` environment variables.

### Using local Ollama models

The bundled `opencode.json` registers Ollama as a provider (`http://localhost:11434/v1`), so models you pull locally show up in the model picker. Add a new model pulled with `ollama pull <model>:<tag>` to the `models` map in `opencode.json`.

## 🚀 Quick Start

1. Make the scripts executable: `chmod +x run.sh scripts/foundation/*.sh scripts/wrapper/*.sh`
2. Run `./run.sh` and choose **option 1** to install dependencies. That chains `installDependencies.sh` (jq, curl, Java, opencode, optionally Ollama), then `buildSqliteManager.sh` (clones and builds the SQLite jar), then `pullOllamaModels.sh`.
3. Choose **option 2** to generate a resume.

Optionally, place a master `personalData.txt` in the project root and `collectPersonalData.sh` will copy it instead of extracting from the database.

## ✅ Verification

Run the self-contained end-to-end test (starts an opencode server, feeds sample data, and asserts the output):

```bash
bash scripts/wrapper/testScript.sh
```

It defaults to the first model from `opencode models`; pass `TEST_MODEL=<n>` to pick a different one, or run it interactively to choose from a list.

The test asserts 24 checks:
- **HTML builder edge cases (offline, no model needed):** localized labels, label fallback, empty category omitted, absent optional contact fields, `&`/`<`/`>`/quote escaping, malformed-JSON rejection
- **Pipeline:** `test/matches.txt` is valid JSON with `profile`, `labels` and the three arrays; `test/resume.html` is generated with the candidate name and rendered sections
- **Edge cases:** empty job title, empty job description, empty database

The builder block runs before the model gate, so `bash scripts/wrapper/testScript.sh` still exercises it when no model is available.

## 🔧 Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `OPENCODE_URL` | `http://localhost:4096` | Base URL of the opencode server |
| `OPENCODE_PORT` | `4096` | Port used when starting a local server |
| `OPENCODE_START_TIMEOUT` | `60` | Seconds to wait for the server to come up |

## 📁 Project Layout

```
run.sh                              # menu: Install dependencies / Generate resume / Exit
scripts/common.sh                   # sourced by every script: constants, need_cmd/need_jar, set -e
scripts/foundation/                 # one job each; never invokes another project script
  askJobTitle.sh                    #   prints the job title on stdout
  selectModel.sh                    #   prints "provider<TAB>model"
  collectJobDescription.sh          #   persists <job>/jobDescription.txt
  collectPersonalData.sh            #   persists <job>/personalData.txt
  checkDependencies.sh              #   lists missing dependencies, exit 1 if any
  installDependencies.sh            #   installs jq, curl, Java, opencode, optionally Ollama
  buildSqliteManager.sh             #   clones + builds sqlite-manager-complete.jar
  pullOllamaModels.sh               #   pulls the models declared in opencode.json
  startOpencodeServer.sh            #   prints the PID of a server it started
  infoMatcher.sh                    #   writes <job>/matches.txt
  resumeBuilder.sh                  #   writes <job>/resume.html
scripts/wrapper/                    # compose foundation scripts
  generateResume.sh                 #   the pipeline
  testScript.sh                     #   the test harness
```

The layer rule is mechanical: **a script that invokes another project script is a
wrapper; anything else is a foundation.** `run.sh` is a wrapper that lives at the
project root so `./run.sh` is the obvious way in.

Every script that prompts accepts an optional argument and prompts only when it is
absent, so the whole pipeline can run non-interactively:

```bash
bash scripts/wrapper/generateResume.sh "Backend Engineer" "opencode/space-bunny-free"
```

## 📂 Output Artifacts

Per-job folder (named after the job title with spaces → underscores):

```
<Job_Title>/
├── personalData.txt    # Career history (extracted from DB or copied from project root)
├── jobDescription.txt  # Target job posting (user-provided)
├── matches.txt         # JSON match report (profile + labels + 3 categories)
└── resume.html         # Self-contained HTML resume
```