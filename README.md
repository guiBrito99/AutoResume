# AutoResume: Local ATS Pipeline

An automated, privacy-first pipeline that generates highly tailored, ATS-optimized resumes using local LLMs. 

Instead of manually rewriting your resume for every application, this project acts as a "reverse Applicant Tracking System." It pulls your master career history from a local SQLite database, cross-references it with a target job description, and uses Ollama to generate a customized resume—all completely offline.

## ✨ Features

* **100% Local & Private:** No personal data is sent to cloud APIs. The entire pipeline runs securely on your machine.
* **Database-Driven History:** Uses [java-sqlite-manager](https://github.com/guiBrito99/java-sqlite-manager) to cleanly store, manage, and retrieve your master list of skills, experiences, and projects.
* **Automated Orchestration:** A smart Bash script creates job-specific directories, detects master templates, extracts database records, and handles all LLM communication.
* **ATS-Optimized Output:** Instructs the local AI to act as a Senior ATS Specialist, ensuring the final output heavily aligns with the target job's keywords and your defined structure rules.

## 🛠️ How It Works

1. **The Database:** Your entire career history (roles, tech stack, highlights) is stored via the `java-sqlite-manager` CLI.
2. **The Context:** You provide a target **Job Description** and your preferred **Structure Rules** (either as master `.txt` files in the root folder or pasted directly into the terminal).
3. **The Script:** `generate_resume.sh` creates a dedicated folder for the specific job, extracts your personal data from the `.jar` application, and constructs a precise JSON payload.
4. **The LLM:** Ollama (defaulting to the `deepseek-r1` model) processes the context and outputs a perfectly tailored `resume.txt` directly into the job folder.

## 📦 Prerequisites

To run this pipeline, you will need the following installed on your system:

* **[Ollama](https://ollama.com/)** running locally.
* A downloaded Ollama model (run `ollama pull deepseek-r1` to get the default model).
* **Java** (to run the `sqlite-manager-complete.jar`).
* **jq** (for secure JSON parsing and payload construction).
* A Linux environment or WSL (for the Bash script).

## 🚀 Quick Start

1. Ensure your `sqlite-manager-complete.jar` and `generate_resume.sh` are in the same root directory.
2. Optionally, create master `personalData.txt` and `structureRules.txt` files in the root directory to skip manual entry.
3. Make the script executable: chmod +x generate_resume.sh
4. Run the pipeline: ./generate_resume.sh
