# AGENTS.md

## Project Overview

AutoResume is a privacy-first, offline resume generator. It acts as a "reverse ATS": given the user's master career history plus a target job posting, it uses the local opencode server (an LLM backed by the user's configured providers) to produce an ATS-optimized resume. No data ever leaves the machine.

## Tech Stack

- **Bash** for orchestration (the entire pipeline is shell scripts — no package.json, Makefile, or build system)
- **SQLite** accessed via `sqlite-manager-complete.jar` (Java CLI, run with `--enable-native-access=ALL-UNNAMED`), from the author's [java-sqlite-manager](https://github.com/guiBrito99/java-sqlite-manager) project
- **opencode** (`opencode serve`) for LLM inference. The script talks to the HTTP/JSON-RPC API it exposes on `http://<host>:<port>` (default `http://localhost:4096`).
- **jq** for safe JSON payload construction
- **curl** for the HTTP calls to the opencode server
- **Java** (JRE) to execute the SQLite manager JAR

## Files

| File | Purpose |
|---|---|
| `generateResume.sh` | Main pipeline entry point. Installs deps, starts/attaches to an opencode server, lets user pick a model (via `opencode models`), takes a job title, gathers per-job context files, builds the JSON payload, posts it to the opencode API, writes `resume.txt`. |
| `testScript.sh` | Self-contained end-to-end test. Creates + populates a SQLite DB (Profile/Education/Experience/Skills), writes sample `persona.txt` and `structureRules.txt`, feeds a sample job description through `generateResume.sh` non-interactively, then runs edge-case checks (empty job title, empty job description, empty DB) and cleans up. 10 assertions, PASS/FAIL summary. |
| `sqlite-manager-complete.jar` | Bundled Java CLI doing SQLite `create`, `insert`, `print`, etc. |
| `README.md` | User-facing docs. |
| `AGENTS.md` | This file. |

## Runtime Directory Layout

At runtime, `generateResume.sh` creates a per-job folder named after the job title (spaces → underscores). Each contains:

```
<Job_Title>/
├── personalData.txt    # Career history (extracted from DB or copied from root master)
├── jobDescription.txt  # Target job posting (user-provided)
├── structureRules.txt  # Formatting/structural constraints (or copied from root master)
├── persona.txt         # System prompt defining the LLM's role
└── resume.txt          # Final generated resume (LLM output)
```

Master templates (`personalData.txt`, `structureRules.txt`, `persona.txt`) placed in the project root are auto-copied into new job folders.

## How `generateResume.sh` talks to opencode

1. **Health check** `curl $OPENCODE_URL/global/health`; if unreachable, starts `opencode serve --port $OPENCODE_PORT` in the background (killed on exit unless a server was already running).
2. **Model selection** from `opencode models` output (`provider/model`), parsed into `providerID`/`modelID` for the API body.
3. **Create session** `POST /session` with `{title}` → extract `.id`.
4. **Send message** `POST /session/:id/message` with body `{model: {providerID, modelID}, system: <persona>, tools: {}, parts: [{type: "text", text: <user prompt>}]}`.
   - `tools: {}` is **required** to disable agent tool calls — otherwise the model may try to write files itself instead of returning the resume text.
5. **Extract answer** via `jq -r '[.parts[] | select(.type == "text") | .text] | join("")'`, filtering out `reasoning`/`step-start`/`step-finish` parts.
6. Error checks: HTTP status != 200, `.error` key, or empty extracted text all abort with a message.

## Key Conventions & Gotchas

- **DB state lives outside the repo at runtime**: `testScript.sh` creates `database.sqlite` in the project root and deletes it during cleanup. A stale `database.sqlite`, `persona.txt`, or `structureRules.txt` in the root can silently short-circuit `generateResume.sh`'s prompts.
- **The JAR command syntax**: `java --enable-native-access=ALL-UNNAMED -jar sqlite-manager-complete.jar <create|insert|print>` with comma-separated column lists and comma-separated row values (see `testScript.sh` for exact usage).
- **Server lifecycle**: if an opencode server is already running at `OPENCODE_URL`, the script attaches to it and does NOT kill it on exit. If it starts its own, an `EXIT` trap kills it and removes temp files.
- **Env overrides**: `OPENCODE_URL`, `OPENCODE_PORT`, `OPENCODE_START_TIMEOUT`.
- **Non-interactive usage**: `testScript.sh` drives `generateResume.sh` by piping input (`printf '1\ntest' | bash generateResume.sh`), where `1` selects the first model from `opencode models` and `test` is the job folder name. In non-interactive runs stdin is consumed in order by the model `select`, the job-title `read`, then any pasted files (`cat`).
- **Output written inline, never by the agent**: `tools: {}` forces the model to return the resume as response text; `generateResume.sh` writes it to `resume.txt`. If the agent is given tools, it may create `resume.txt` in the project root instead — regression to watch for.
- **Language**: prompts and the user prompt prefix (`"Aqui estão os dados:"`) are Portuguese; generated resumes are expected in the language dictated by the persona/ job description.

## Verification

There is no test framework. To validate changes:
1. Run `bash testScript.sh` (requires opencode installed, logged in to a provider, and network-free model availability). Expect `10 passed | 0 failed`.
2. Inspect the generated `test/resume.txt`, then check the root is clean of artifacts (`resume.txt`, `database.sqlite`, `persona.txt`, `structureRules.txt` are removed by the trap).
3. Syntax is checked with `bash -n <script>`.
4. After any structural change to the pipeline, re-run an end-to-end generation and confirm `test/resume.txt` contains candidate data, not agent commentary.