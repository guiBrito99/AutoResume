#!/bin/bash

# 1 - Populate the database (Integrated logic)
# Color formatting
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Setup paths and JVM arguments
JAR_PATH="sqlite-manager-complete.jar"
ABS_JAR_PATH="$PWD/$JAR_PATH"
JVM_ARGS="--enable-native-access=ALL-UNNAMED"

echo -e "${CYAN}=== Generating Resume Database ===${NC}"

# Create Relational Tables for a Resume
echo -e "\n${YELLOW}Building Schema...${NC}"
java $JVM_ARGS -jar "$ABS_JAR_PATH" create Profile id,full_name,target_role,email
java $JVM_ARGS -jar "$ABS_JAR_PATH" create Education id,institution,degree,status
java $JVM_ARGS -jar "$ABS_JAR_PATH" create Experience id,company,role,year
java $JVM_ARGS -jar "$ABS_JAR_PATH" create Skills id,category,skill_name

# Insert Baseline Resume Data
echo -e "\n${GREEN}Populating Profile...${NC}"
java $JVM_ARGS -jar "$ABS_JAR_PATH" insert Profile id,full_name,target_role,email 1,Jane_Doe,Data_Engineer,jane.doe@example.com

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

# 2 - Create persona.txt
cat << 'EOF' > persona.txt
You are a Senior ATS (Applicant Tracking System) Specialist and Expert Technical Recruiter. Your objective is to act as an elite resume writer.

You will analyze the candidate's personal data, a target job description, and a set of strict structure rules. Your goal is to synthesize the candidate's background into a highly optimized, compelling resume that perfectly aligns with the target job's requirements.

You must naturally weave in keywords from the job description to ensure a high ATS match rate, while maintaining a persuasive, professional tone that appeals to human hiring managers. You must strictly obey all formatting and structural constraints provided in the structure rules.
EOF

# 3 - Create structureRules.txt
cat << 'EOF' > structureRules.txt
- The resume must be formatted strictly in Markdown.
- Limit the content to a maximum of one page.
- Do not invent, hallucinate, or assume any skills, experiences, or metrics that are not explicitly provided in the Personal Data file.
- Required Sections (in exact order): Header (Name and Contact Info), Professional Summary, Work Experience, Technical Skills, Education.
- Professional Summary must be exactly 3 sentences focusing on alignment with the target role.
- Work Experience entries must use bullet points (maximum 4 bullets per role).
- Every bullet point must begin with a strong action verb (e.g., Engineered, Designed, Optimized).
- Naturally integrate exact keywords and phrases from the Job Description into the Work Experience and Technical Skills sections.
- Keep all section headings standard (e.g., use "Work Experience" instead of "Professional Journey") to ensure ATS parsing compatibility.
- Do not include references, hobbies, or objective statements.
EOF

# 4 - Create the folder test
mkdir -p test

# 5 - Create jobDescription.txt inside the test folder
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

# 6 - Run generateResume.sh and force the first command to be "test"
echo "test" | bash generateResume.sh

# 7 - Cleanup the generated root files while leaving the copies in the test folder intact
rm persona.txt structureRules.txt database.sqlite
