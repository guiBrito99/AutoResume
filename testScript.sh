#!/bin/bash

# Color formatting
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Test bookkeeping
PASS=0
FAIL=0

check() { # check <name> <command-string>
    local name="$1" cond="$2"
    if bash -c "$cond"; then
        echo -e "${GREEN}  PASS: $name${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}  FAIL: $name${NC}"
        FAIL=$((FAIL + 1))
    fi
}

# Robust cleanup: run on every exit, even mid-test failures
cleanup() {
    rm -f database.sqlite edge_out.txt main_out.txt
    rm -rf edge_db edge_title edge_job
}
trap cleanup EXIT

# Setup paths and JVM arguments
JAR_PATH="sqlite-manager-complete.jar"
ABS_JAR_PATH="$PWD/$JAR_PATH"
JVM_ARGS="--enable-native-access=ALL-UNNAMED"

echo -e "${CYAN}=== Generating Resume Database ===${NC}"

# Create Relational Tables for a Resume
echo -e "\n${YELLOW}Building Schema...${NC}"
java $JVM_ARGS -jar "$ABS_JAR_PATH" create Profile id,full_name,target_role,email,phone,location,linkedin,github
java $JVM_ARGS -jar "$ABS_JAR_PATH" create Education id,institution,degree,status
java $JVM_ARGS -jar "$ABS_JAR_PATH" create Experience id,company,role,year
java $JVM_ARGS -jar "$ABS_JAR_PATH" create Skills id,category,skill_name

# Insert Baseline Resume Data
echo -e "\n${GREEN}Populating Profile...${NC}"
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Profile id,full_name,target_role,email,phone,location,linkedin,github 1,Jane_Doe,Data_Engineer,jane.doe@example.com,+15550100,Remote,https://linkedin.com/in/janedoe,https://github.com/janedoe

echo -e "${GREEN}Populating Education...${NC}"
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Education id,institution,degree,status 1,State_University,Computer_Science,Graduated
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Education id,institution,degree,status 2,Tech_Institute,Data_Analytics,Completed

echo -e "${GREEN}Populating Experience...${NC}"
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Experience id,company,role,year 1,Tech_Corp,Junior_Data_Engineer,2025
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Experience id,company,role,year 2,Data_Solutions,Data_Analyst_Intern,2024
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Experience id,company,role,year 3,Web_Services_LLC,QA_Intern,2023

echo -e "${GREEN}Populating Skills...${NC}"
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Skills id,category,skill_name 1,Backend,Python
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Skills id,category,skill_name 2,Scripting,Bash
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Skills id,category,skill_name 3,Cloud,AWS
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Skills id,category,skill_name 4,Database,PostgreSQL
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Skills id,category,skill_name 5,Architecture,Microservices

# Print the Result
echo -e "\n${CYAN}=== Final Database State ===${NC}"
java $JVM_ARGS -jar "$ABS_JAR_PATH" print

# 2 - Create the folder test with its job description
mkdir -p test

cat << 'EOF' > test/jobDescription.txt
Job Title: Backend Systems Engineer
Company: AuraSphere Dynamics
Location: Remote

About the Role:
AuraSphere Dynamics is seeking a Backend Systems Engineer to scale our core data processing API. You will join a fast-paced engineering team dedicated to building resilient and high-performance server-side architectures for our cloud-based inventory platform.

Key Responsibilities:
- Design, build, and maintain efficient, reusable, and reliable backend code using Python and Django.
- Integrate user-facing elements developed by frontend developers with server-side logic.
- Implement security and data protection measures across all endpoints.
- Optimize SQL queries and database schemas for PostgreSQL to ensure maximum performance.

Required Qualifications:
- 3+ years of professional experience in backend development.
- Strong proficiency in Python, RESTful APIs, and relational databases.
- Experience with containerization tools, specifically Docker.
- Solid understanding of Git version control.
- Ability to write clean, testable code and participate in peer code reviews.

Nice to Have:
- Experience working with AWS (EC2, S3, RDS).
- Familiarity with CI/CD pipelines.
EOF

# 3 - Choose which model to run the test against
MODEL_CHOICE="${TEST_MODEL:-}"
if [ -z "$MODEL_CHOICE" ]; then
    AVAILABLE_MODELS=$(opencode models 2>/dev/null)
    if [ -z "$AVAILABLE_MODELS" ]; then
        echo -e "${RED}❌ No models available. Run 'opencode auth login' or add a provider first.${NC}"
        exit 1
    fi
    if [ -t 0 ]; then
        echo -e "\n${CYAN}Available models:${NC}"
        nl -w2 -s'. ' <<< "$AVAILABLE_MODELS"
        read -r -p "Enter the number of the model to test (default: 1): " MODEL_CHOICE
        MODEL_CHOICE="${MODEL_CHOICE:-1}"
    else
        MODEL_CHOICE=1
    fi
fi

case "$MODEL_CHOICE" in
    *[!0-9]* | "")
        echo -e "${YELLOW}Invalid model choice '$MODEL_CHOICE'; falling back to model 1.${NC}"
        MODEL_CHOICE=1
        ;;
esac

echo -e "Using model selection: $MODEL_CHOICE ($(opencode models 2>/dev/null | sed -n "${MODEL_CHOICE}p"))"

# 4 - Main happy-path run: pass the selected model and "test" (folder name)
echo -e "\n${CYAN}=== Running generateResume.sh (happy path) ===${NC}"
printf '%s\ntest\n' "$MODEL_CHOICE" | bash generateResume.sh > main_out.txt 2>&1
MAIN_CODE=$?

check "exits successfully" "test $MAIN_CODE -eq 0"
check "creates matches.txt" 'test -s test/matches.txt'
check "matches.txt is valid JSON" 'jq -e . test/matches.txt >/dev/null 2>&1'
check "matches has profile with full_name" 'jq -e ".profile.full_name" test/matches.txt >/dev/null 2>&1'
check "matches has labels object" 'jq -e ".labels" test/matches.txt >/dev/null 2>&1'
check "matches has experience array" 'jq -e ".experience | type == \"array\"" test/matches.txt >/dev/null 2>&1'
check "matches has education array" 'jq -e ".education | type == \"array\"" test/matches.txt >/dev/null 2>&1'
check "matches has skills array" 'jq -e ".skills | type == \"array\"" test/matches.txt >/dev/null 2>&1'
check "creates resume.html" 'test -s test/resume.html'
check "resume.html contains candidate name" 'grep -qi "jane" test/resume.html'
check "resume.html has Experience section" 'grep -q "Experiência\|Experience" test/resume.html'

# 5 - Edge case: empty job title
echo -e "\n${CYAN}=== Edge case: empty job title ===${NC}"
printf '%s\n\n' "$MODEL_CHOICE" | bash generateResume.sh > edge_out.txt 2>&1
EDGE_TITLE_CODE=$?
check "rejects empty job title" "test $EDGE_TITLE_CODE -ne 0"
check "prints job-title error" 'grep -q "Job title cannot be empty" edge_out.txt'

# 6 - Edge case: empty pasted job description
echo -e "\n${CYAN}=== Edge case: empty pasted job description ===${NC}"
printf '%s\nedge_job\n' "$MODEL_CHOICE" | bash generateResume.sh > edge_out.txt 2>&1
EDGE_JOB_CODE=$?
check "rejects empty job description" "test $EDGE_JOB_CODE -ne 0"
check "prints job-description error" 'grep -q "jobDescription.txt is empty" edge_out.txt'

# 7 - Edge case: empty database
echo -e "\n${CYAN}=== Edge case: empty database ===${NC}"
rm -f database.sqlite
printf '%s\nedge_db\n' "$MODEL_CHOICE" | bash generateResume.sh > edge_out.txt 2>&1
EDGE_DB_CODE=$?
check "rejects empty database" "test $EDGE_DB_CODE -ne 0"
check "prints empty-database error" 'grep -q "database is empty" edge_out.txt'

# 8 - Summary + cleanup (trap removes root artifacts)
echo -e "\n${CYAN}=== Results ===${NC}"
echo -e "${GREEN}${PASS} passed${NC} | ${RED}${FAIL} failed${NC}"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
echo -e "\nInspect the generated match report at test/matches.txt"
echo -e "Inspect the generated HTML resume at test/resume.html"