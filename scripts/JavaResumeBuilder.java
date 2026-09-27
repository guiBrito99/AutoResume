import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class JavaResumeBuilder {

    public static void main(String[] args) {
        if (args.length != 2) {
            System.err.println("Usage: java JavaResumeBuilder.java <matches.txt> <resume.html>");
            System.exit(1);
        }

        try {
            String json = Files.readString(Path.of(args[0]));
            Object parsed = new JsonParser(json).parse();

            if (!(parsed instanceof Map)) {
                System.err.println("Error: matches.txt does not contain a JSON object.");
                System.exit(1);
            }

            @SuppressWarnings("unchecked")
            Map<String, Object> root = (Map<String, Object>) parsed;

            String html = buildHtml(root);
            Files.writeString(Path.of(args[1]), html);
            System.out.println("HTML resume written to " + args[1]);
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            System.exit(1);
        }
    }

    private static String buildHtml(Map<String, Object> root) {
        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n");
        sb.append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n");
        Map<String, Object> profile = obj(root, "profile");
        String title = esc(profile != null ? str(profile.get("full_name")) : "", "Resume");
        sb.append("<title>").append(title).append("</title>\n");
        sb.append("<style>\n");
        sb.append(css());
        sb.append("</style>\n</head>\n<body>\n");

        renderHeader(sb, obj(root, "profile"));
        renderSections(sb, root);

        sb.append("</body>\n</html>\n");
        return sb.toString();
    }

    private static void renderHeader(StringBuilder sb, Map<String, Object> profile) {
        if (profile == null) {
            return;
        }

        String name = str(profile.get("full_name"));
        String targetRole = str(profile.get("target_role"));

        sb.append("<header>\n");
        if (!name.isEmpty()) {
            sb.append("<h1>").append(esc(name, "")).append("</h1>\n");
        }
        if (!targetRole.isEmpty()) {
            sb.append("<p class=\"target-role\">").append(esc(targetRole, "")).append("</p>\n");
        }
        renderContact(sb, profile);
        sb.append("</header>\n");
    }

    private static void renderContact(StringBuilder sb, Map<String, Object> profile) {
        List<String> pieces = new ArrayList<>();

        String email = str(profile.get("email"));
        if (!email.isEmpty()) {
            pieces.add("<a href=\"mailto:" + escAttr(email) + "\">" + esc(email, "") + "</a>");
        }

        String phone = str(profile.get("phone"));
        if (!phone.isEmpty()) {
            pieces.add(esc(phone, ""));
        }

        String location = str(profile.get("location"));
        if (!location.isEmpty()) {
            pieces.add(esc(location, ""));
        }

        String linkedin = str(profile.get("linkedin"));
        if (!linkedin.isEmpty()) {
            pieces.add("<a href=\"" + escAttr(linkedin) + "\" rel=\"noopener\" target=\"_blank\">LinkedIn</a>");
        }

        String github = str(profile.get("github"));
        if (!github.isEmpty()) {
            pieces.add("<a href=\"" + escAttr(github) + "\" rel=\"noopener\" target=\"_blank\">GitHub</a>");
        }

        if (!pieces.isEmpty()) {
            sb.append("<p class=\"contact\">").append(String.join(" · ", pieces)).append("</p>\n");
        }
    }

    private static void renderSections(StringBuilder sb, Map<String, Object> root) {
        Map<String, Object> labels = obj(root, "labels");
        String[] keys = {"experience", "education", "skills"};

        for (String key : keys) {
            Object raw = root.get(key);
            if (!(raw instanceof List)) {
                continue;
            }
            @SuppressWarnings("unchecked")
            List<Object> items = (List<Object>) raw;
            if (items.isEmpty()) {
                continue;
            }

            String heading = labelFor(labels, key);
            boolean dense = items.size() > 6;

            sb.append("<section>\n");
            sb.append("<h2>").append(esc(heading, "")).append("</h2>\n");
            sb.append(dense ? "<ul class=\"grid grid-2\">\n" : "<ul class=\"grid\">\n");

            for (Object item : items) {
                if (!(item instanceof Map)) {
                    continue;
                }
                @SuppressWarnings("unchecked")
                Map<String, Object> match = (Map<String, Object>) item;
                String requirement = str(match.get("requirement"));
                String evidence = str(match.get("evidence"));

                sb.append("<li>\n");
                if (!requirement.isEmpty()) {
                    sb.append("<span class=\"req\">").append(esc(requirement, "")).append("</span>\n");
                }
                if (!evidence.isEmpty()) {
                    sb.append("<span class=\"ev\">").append(esc(evidence, "")).append("</span>\n");
                }
                sb.append("</li>\n");
            }

            sb.append("</ul>\n</section>\n");
        }
    }

    private static String labelFor(Map<String, Object> labels, String key) {
        if (labels != null) {
            String label = str(labels.get(key));
            if (!label.isEmpty()) {
                return label;
            }
        }
        return titleCase(key);
    }

    private static String titleCase(String key) {
        if (key.isEmpty()) {
            return key;
        }
        return Character.toUpperCase(key.charAt(0)) + key.substring(1);
    }

    private static Map<String, Object> obj(Map<String, Object> parent, String key) {
        Object value = parent.get(key);
        if (value instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> map = (Map<String, Object>) value;
            return map;
        }
        return null;
    }

    private static String str(Object value) {
        if (value == null) {
            return "";
        }
        return String.valueOf(value);
    }

    private static String esc(String value, String fallback) {
        if (value == null || value.isEmpty()) {
            return fallback;
        }
        return value
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }

    private static String escAttr(String value) {
        return esc(value, "");
    }

    private static String css() {
        return "*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}\n"
                + "body{font-family:\"Segoe UI\",system-ui,-apple-system,Roboto,Helvetica,Arial,sans-serif;color:#1f2937;background:#f3f4f6;line-height:1.5;padding:2rem 1rem;}\n"
                + "body>*{max-width:800px;margin:0 auto;}\n"
                + "header{padding:1.75rem 2rem;background:#ffffff;border-bottom:4px solid #2563eb;}\n"
                + "h1{font-size:2rem;letter-spacing:.5px;}\n"
                + ".target-role{color:#2563eb;font-weight:600;margin-top:.25rem;font-size:1.1rem;}\n"
                + ".contact{margin-top:.75rem;font-size:.9rem;color:#4b5563;word-break:break-word;}\n"
                + ".contact a,.contact a:visited{color:#2563eb;text-decoration:none;}\n"
                + ".contact a:hover{text-decoration:underline;}\n"
                + "main,section,.grid{display:block;}\n"
                + "section{background:#ffffff;padding:1.5rem 2rem;margin-top:1rem;}\n"
                + "h2{font-size:1.15rem;text-transform:uppercase;letter-spacing:1px;color:#111827;border-bottom:1px solid #e5e7eb;padding-bottom:.5rem;margin-bottom:1rem;}\n"
                + ".grid{list-style:none;display:grid;gap:.9rem;grid-template-columns:1fr;}\n"
                + ".grid-2{grid-template-columns:1fr 1fr;}\n"
                + "@media(max-width:640px){.grid-2{grid-template-columns:1fr;}}\n"
                + "li{background:#f9fafb;border:1px solid #e5e7eb;border-radius:6px;padding:.75rem .9rem;}\n"
                + ".req{display:block;font-weight:600;font-size:.95rem;color:#111827;}\n"
                + ".ev{display:block;margin-top:.35rem;font-size:.88rem;color:#4b5563;}\n"
                + "@media print{body{background:#ffffff;padding:0;}section,header{box-shadow:none;margin-top:0;border-radius:0;}\n"
                + ".grid-2{grid-template-columns:1fr 1fr;}}\n";
    }

    private static class JsonParser {
        private final String src;
        private int pos;

        JsonParser(String src) {
            this.src = src;
        }

        Object parse() {
            Object value = parseValue();
            skipWs();
            if (pos < src.length()) {
                throw new IllegalArgumentException("Unexpected trailing characters at index " + pos);
            }
            return value;
        }

        private Object parseValue() {
            skipWs();
            if (pos >= src.length()) {
                throw new IllegalArgumentException("Unexpected end of input");
            }
            char c = src.charAt(pos);
            switch (c) {
                case '{':
                    return parseObject();
                case '[':
                    return parseArray();
                case '"':
                    return parseString();
                case 't':
                case 'f':
                    return parseBoolean();
                case 'n':
                    return parseNull();
                default:
                    if (c == '-' || (c >= '0' && c <= '9')) {
                        return parseNumber();
                    }
                    throw new IllegalArgumentException("Unexpected character '" + c + "' at index " + pos);
            }
        }

        private Map<String, Object> parseObject() {
            Map<String, Object> map = new LinkedHashMap<>();
            pos++;
            skipWs();
            if (peek() == '}') {
                pos++;
                return map;
            }
            while (true) {
                skipWs();
                if (peek() != '"') {
                    throw new IllegalArgumentException("Expected string key at index " + pos);
                }
                String key = parseString();
                skipWs();
                if (peek() != ':') {
                    throw new IllegalArgumentException("Expected ':' at index " + pos);
                }
                pos++;
                Object value = parseValue();
                map.put(key, value);
                skipWs();
                char c = peek();
                if (c == ',') {
                    pos++;
                } else if (c == '}') {
                    pos++;
                    return map;
                } else {
                    throw new IllegalArgumentException("Expected ',' or '}' at index " + pos);
                }
            }
        }

        private List<Object> parseArray() {
            List<Object> list = new ArrayList<>();
            pos++;
            skipWs();
            if (peek() == ']') {
                pos++;
                return list;
            }
            while (true) {
                list.add(parseValue());
                skipWs();
                char c = peek();
                if (c == ',') {
                    pos++;
                } else if (c == ']') {
                    pos++;
                    return list;
                } else {
                    throw new IllegalArgumentException("Expected ',' or ']' at index " + pos);
                }
            }
        }

        private String parseString() {
            pos++;
            StringBuilder sb = new StringBuilder();
            while (pos < src.length()) {
                char c = src.charAt(pos++);
                if (c == '"') {
                    return sb.toString();
                }
                if (c == '\\') {
                    if (pos >= src.length()) {
                        throw new IllegalArgumentException("Unterminated escape at index " + pos);
                    }
                    char e = src.charAt(pos++);
                    switch (e) {
                        case '"':
                            sb.append('"');
                            break;
                        case '\\':
                            sb.append('\\');
                            break;
                        case '/':
                            sb.append('/');
                            break;
                        case 'b':
                            sb.append('\b');
                            break;
                        case 'f':
                            sb.append('\f');
                            break;
                        case 'n':
                            sb.append('\n');
                            break;
                        case 'r':
                            sb.append('\r');
                            break;
                        case 't':
                            sb.append('\t');
                            break;
                        case 'u':
                            if (pos + 4 > src.length()) {
                                throw new IllegalArgumentException("Truncated \\u escape at index " + pos);
                            }
                            String hex = src.substring(pos, pos + 4);
                            sb.append((char) Integer.parseInt(hex, 16));
                            pos += 4;
                            break;
                        default:
                            throw new IllegalArgumentException("Invalid escape '\\" + e + "' at index " + (pos - 1));
                    }
                } else {
                    sb.append(c);
                }
            }
            throw new IllegalArgumentException("Unterminated string");
        }

        private Boolean parseBoolean() {
            if (src.startsWith("true", pos)) {
                pos += 4;
                return Boolean.TRUE;
            }
            if (src.startsWith("false", pos)) {
                pos += 5;
                return Boolean.FALSE;
            }
            throw new IllegalArgumentException("Invalid literal at index " + pos);
        }

        private Object parseNull() {
            if (src.startsWith("null", pos)) {
                pos += 4;
                return null;
            }
            throw new IllegalArgumentException("Invalid literal at index " + pos);
        }

        private Number parseNumber() {
            int start = pos;
            if (peek() == '-') {
                pos++;
            }
            while (pos < src.length() && Character.isDigit(src.charAt(pos))) {
                pos++;
            }
            if (pos < src.length() && src.charAt(pos) == '.') {
                pos++;
                while (pos < src.length() && Character.isDigit(src.charAt(pos))) {
                    pos++;
                }
            }
            if (pos < src.length() && (src.charAt(pos) == 'e' || src.charAt(pos) == 'E')) {
                pos++;
                if (pos < src.length() && (src.charAt(pos) == '+' || src.charAt(pos) == '-')) {
                    pos++;
                }
                while (pos < src.length() && Character.isDigit(src.charAt(pos))) {
                    pos++;
                }
            }
            String token = src.substring(start, pos);
            try {
                return token.contains(".") || token.contains("e") || token.contains("E")
                        ? (Number) Double.parseDouble(token)
                        : Long.parseLong(token);
            } catch (NumberFormatException ex) {
                throw new IllegalArgumentException("Invalid number '" + token + "'");
            }
        }

        private void skipWs() {
            while (pos < src.length() && Character.isWhitespace(src.charAt(pos))) {
                pos++;
            }
        }

        private char peek() {
            if (pos >= src.length()) {
                throw new IllegalArgumentException("Unexpected end of input");
            }
            return src.charAt(pos);
        }
    }
}