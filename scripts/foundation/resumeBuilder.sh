#!/bin/bash

# Single job: render matches.txt into a self-contained HTML resume.
#
# Usage: resumeBuilder.sh <matches.txt> <resume.html>
#
# HTML escaping is delegated to jq's @html filter so there is no
# replace-ordering hazard (an unescaped `&` would otherwise double-escape).
# Section order is fixed: experience, education, skills; empty sections are
# omitted. Headings come from the optional `labels` object, falling back to the
# English key. Layout switches to two columns past six items per section.

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

need_cmd jq

if [ $# -ne 2 ]; then
    echo "Usage: resumeBuilder.sh <matches.txt> <resume.html>" >&2
    exit 1
fi

MATCHES="$1"
OUTFILE="$2"

if [ ! -f "$MATCHES" ]; then
    echo "❌ Matches file not found: $MATCHES" >&2
    exit 1
fi

# Validates the whole document up front so malformed JSON fails here rather than
# silently producing a half-rendered page.
if ! jq -e . "$MATCHES" &> /dev/null; then
    echo "❌ $MATCHES is not valid JSON." >&2
    exit 1
fi

# HTML-escaped value for a jq filter, empty string when absent.
# The extra parentheses keep the `//` default independent of jq's `|` precedence.
esc() {
    jq -r "((($1) // \"\") | @html)" "$MATCHES"
}

# Plain value for a jq filter, empty string when absent.
plain() {
    jq -r "(($1) // \"\")" "$MATCHES"
}

read_css() {
    cat <<'CSS'
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
body{font-family:"Segoe UI",system-ui,-apple-system,Roboto,Helvetica,Arial,sans-serif;color:#1f2937;background:#f3f4f6;line-height:1.5;padding:2rem 1rem;}
body>*{max-width:800px;margin:0 auto;}
header{padding:1.75rem 2rem;background:#ffffff;border-bottom:4px solid #2563eb;}
h1{font-size:2rem;letter-spacing:.5px;}
.target-role{color:#2563eb;font-weight:600;margin-top:.25rem;font-size:1.1rem;}
.contact{margin-top:.75rem;font-size:.9rem;color:#4b5563;word-break:break-word;}
.contact a,.contact a:visited{color:#2563eb;text-decoration:none;}
.contact a:hover{text-decoration:underline;}
main,section,.grid{display:block;}
section{background:#ffffff;padding:1.5rem 2rem;margin-top:1rem;}
h2{font-size:1.15rem;text-transform:uppercase;letter-spacing:1px;color:#111827;border-bottom:1px solid #e5e7eb;padding-bottom:.5rem;margin-bottom:1rem;}
.grid{list-style:none;display:grid;gap:.9rem;grid-template-columns:1fr;}
.grid-2{grid-template-columns:1fr 1fr;}
@media(max-width:640px){.grid-2{grid-template-columns:1fr;}}
li{background:#f9fafb;border:1px solid #e5e7eb;border-radius:6px;padding:.75rem .9rem;}
.req{display:block;font-weight:600;font-size:.95rem;color:#111827;}
.ev{display:block;margin-top:.35rem;font-size:.88rem;color:#4b5563;}
@media print{body{background:#ffffff;padding:0;}section,header{box-shadow:none;margin-top:0;border-radius:0;}
.grid-2{grid-template-columns:1fr 1fr;}}
CSS
}

render_header() {
    local name role
    name=$(esc '.profile.full_name')
    role=$(esc '.profile.target_role')

    [ -n "$name" ] || [ -n "$role" ] || return 0

    printf '<header>\n'
    if [ -n "$name" ]; then
        printf '<h1>%s</h1>\n' "$name"
    fi
    if [ -n "$role" ]; then
        printf '<p class="target-role">%s</p>\n' "$role"
    fi
    render_contact
    printf '</header>\n'
}

render_contact() {
    local pieces=() email phone location linkedin github joined="" p

    email=$(esc '.profile.email')
    if [ -n "$email" ]; then
        pieces+=("<a href=\"mailto:$email\">$email</a>")
    fi

    phone=$(esc '.profile.phone')
    if [ -n "$phone" ]; then
        pieces+=("$phone")
    fi

    location=$(esc '.profile.location')
    if [ -n "$location" ]; then
        pieces+=("$location")
    fi

    linkedin=$(esc '.profile.linkedin')
    if [ -n "$linkedin" ]; then
        pieces+=("<a href=\"$linkedin\" rel=\"noopener\" target=\"_blank\">LinkedIn</a>")
    fi

    github=$(esc '.profile.github')
    if [ -n "$github" ]; then
        pieces+=("<a href=\"$github\" rel=\"noopener\" target=\"_blank\">GitHub</a>")
    fi

    if [ ${#pieces[@]} -gt 0 ]; then
        for p in "${pieces[@]}"; do
            if [ -z "$joined" ]; then
                joined="$p"
            else
                joined="$joined · $p"
            fi
        done
        printf '<p class="contact">%s</p>\n' "$joined"
    fi
}

render_section() {
    local key="$1" fallback="$2"
    local count heading class i req ev

    count=$(plain "(.$key // []) | length")
    case "$count" in
        '' | *[!0-9]*) count=0 ;;
    esac
    if [ "$count" -eq 0 ]; then
        return 0
    fi

    heading=$(esc ".labels.$key")
    if [ -z "$heading" ]; then
        heading="$fallback"
    fi

    if [ "$count" -gt 6 ]; then
        class="grid grid-2"
    else
        class="grid"
    fi

    printf '<section>\n'
    printf '<h2>%s</h2>\n' "$heading"
    printf '<ul class="%s">\n' "$class"

    for ((i = 0; i < count; i++)); do
        req=$(esc ".$key[$i].requirement")
        ev=$(esc ".$key[$i].evidence")
        printf '<li>\n'
        if [ -n "$req" ]; then
            printf '<span class="req">%s</span>\n' "$req"
        fi
        if [ -n "$ev" ]; then
            printf '<span class="ev">%s</span>\n' "$ev"
        fi
        printf '</li>\n'
    done

    printf '</ul>\n</section>\n'
}

{
    title=$(esc '.profile.full_name')
    if [ -z "$title" ]; then
        title="Resume"
    fi

    printf '<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
    printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
    printf '<title>%s</title>\n' "$title"
    printf '<style>\n'
    read_css
    printf '</style>\n</head>\n<body>\n'

    render_header
    render_section "experience" "Experience"
    render_section "education" "Education"
    render_section "skills" "Skills"

    printf '</body>\n</html>\n'
} > "$OUTFILE"

echo "HTML resume written to $OUTFILE"
