#!/usr/bin/env bash
#
# Initializes this template into a concrete TypeScript project (POSIX counterpart
# of init.ps1 — use whichever matches your shell; both do the same thing).
#
# Replaces the placeholder tokens in file contents AND in file/folder names, then
# removes the template-only files (TEMPLATE.md, docs/AGENT-INIT-GUIDE.md) and —
# unless --keep-script — both initializers (init.sh and init.ps1).
#
# Two name tokens are stamped:
#   __ProjectName__  — the project / repo name, used verbatim (e.g.
#                      "Acme.Widgets"). Goes into URLs, LICENSE, docs.
#   __PackageName__  — the npm package name, DERIVED from the project name
#                      (lowercased, runs of non-alphanumerics -> '-', trimmed) —
#                      e.g. "Acme.Widgets" -> "acme-widgets". Goes into
#                      package.json `name` and the README install/usage lines.
#
# Usage:
#   bash ./scripts/init.sh --project-name Acme.Widgets \
#       [--author "Jane Doe"] [--author-email you@example.com] \
#       [--github-owner acme] [--description "Widget toolkit"] \
#       [--year 2026] [--keep-script]

set -euo pipefail

project_name=""
author=""
author_email=""
github_owner=""
description=""
year=""
keep_script=0

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --project-name) project_name="${2:-}"; shift 2 ;;
    --author)       author="${2:-}"; shift 2 ;;
    --author-email) author_email="${2:-}"; shift 2 ;;
    --github-owner) github_owner="${2:-}"; shift 2 ;;
    --description)  description="${2:-}"; shift 2 ;;
    --year)         year="${2:-}"; shift 2 ;;
    --keep-script)  keep_script=1; shift ;;
    -h|--help)      sed -n '2,22p' "$0"; exit 0 ;;
    *)              die "unknown argument: $1" ;;
  esac
done

[ -n "$project_name" ] || die "--project-name is required (e.g. --project-name Acme.Widgets)."

# Validate the project name: ASCII letters, digits, '.', '-', '_', starting and
# ending with an alphanumeric. An out-of-set character (space, '/', '!', ...)
# would produce broken URLs and an underivable npm name — reject it here with a
# clear message.
case "$project_name" in
  *[!A-Za-z0-9._-]*) die "invalid --project-name '$project_name'. Use ASCII letters, digits, '.', '-', '_' (e.g. Acme.Widgets)." ;;
esac
case "$project_name" in
  [A-Za-z0-9]*) : ;;
  *) die "invalid --project-name '$project_name'. It must start with a letter or digit (e.g. Acme.Widgets)." ;;
esac
case "$project_name" in
  *[A-Za-z0-9]) : ;;
  *) die "invalid --project-name '$project_name'. It must end with a letter or digit (e.g. Acme.Widgets)." ;;
esac

# Derive the npm package name: lowercase, collapse runs of non-alphanumerics to
# '-', trim leading/trailing '-'. npm names may start with a digit, so no prefix
# is needed — only the registry's 214-character cap is enforced.
package_name="$(printf '%s' "$project_name" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-*//' -e 's/-*$//')"
[ -n "$package_name" ] || die "invalid --project-name '$project_name'. It must contain at least one ASCII letter or digit so an npm package name can be derived (e.g. Acme.Widgets)."
[ "${#package_name}" -le 214 ] || die "invalid --project-name '$project_name'. The derived npm name exceeds npm's 214-character limit."

# Defaults (mirror init.ps1).
if [ -z "$author" ]; then
  author="$(git config user.name 2>/dev/null || true)"
  [ -n "$author" ] || author="Your Name"
fi
if [ -z "$author_email" ]; then
  author_email="$(git config user.email 2>/dev/null || true)"
  [ -n "$author_email" ] || author_email="you@example.com"
fi
[ -n "$github_owner" ] || github_owner="your-org"
[ -n "$description" ]  || description="TODO: project description"
[ -n "$year" ]         || year="$(date +%Y)"

# Mirror init.ps1's [int]$Year parameter: reject a non-numeric year instead of
# stamping it verbatim into LICENSE.
case "$year" in
  *[!0-9]*|'') die "invalid --year '$year'. Use a numeric year (e.g. $(date +%Y))." ;;
esac

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
self="$script_dir/$(basename "$0")"
sibling_ps1="$script_dir/init.ps1"

# Values written into JSON strings (package.json name/description/author/urls)
# sit inside double-quoted strings — escape backslash then quote so a literal "
# or \ in an author/description can't break the manifest. The derived package
# name is [a-z0-9-] only, so it needs no escaping.
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
project_j="$(json_escape "$project_name")"
author_j="$(json_escape "$author")"
author_email_j="$(json_escape "$author_email")"
owner_j="$(json_escape "$github_owner")"
desc_j="$(json_escape "$description")"
year_j="$(json_escape "$year")"

echo "==> Initializing template as '$project_name' (npm package '$package_name')"

# Literal, backslash-safe token replacement via awk's ENVIRON (no escape
# processing, unlike bash's ${var//pat/repl} which mangles doubled backslashes).
# The whole file is handled in BEGIN so no record splitting adds/drops a newline.
substitute_tokens() {
  awk '
    function repl(s, tok, val,   out, i) {
      out = ""
      while ((i = index(s, tok)) > 0) {
        out = out substr(s, 1, i - 1) val
        s = substr(s, i + length(tok))
      }
      return out s
    }
    BEGIN {
      s = ENVIRON["TPL_SRC"]
      s = repl(s, "__ProjectName__", ENVIRON["TPL_PROJECT"])
      s = repl(s, "__PackageName__", ENVIRON["TPL_PACKAGE"])
      s = repl(s, "__Author__",      ENVIRON["TPL_AUTHOR"])
      s = repl(s, "__AuthorEmail__", ENVIRON["TPL_AUTHOR_EMAIL"])
      s = repl(s, "__GitHubOwner__", ENVIRON["TPL_OWNER"])
      s = repl(s, "__Description__", ENVIRON["TPL_DESC"])
      s = repl(s, "__Year__",        ENVIRON["TPL_YEAR"])
      printf "%s", s
    }'
}

# 1) Replace tokens in file contents. Both initializers are skipped: they carry
#    the literal token strings as search keys, so substituting inside them would
#    corrupt the sibling script. Build output dirs are pruned.
changed=0
while IFS= read -r -d '' file; do
  case "$file" in
    "$self"|"$sibling_ps1") continue ;;
  esac
  case "$file" in
    *.json) p=$project_j; a=$author_j; ae=$author_email_j; o=$owner_j; d=$desc_j; y=$year_j ;;
    *)      p=$project_name; a=$author; ae=$author_email; o=$github_owner; d=$description; y=$year ;;
  esac
  # Preserve trailing newlines: append a sentinel before capture, strip it after.
  content="$(cat "$file"; printf x)"; content="${content%x}"
  new="$(TPL_SRC="$content" TPL_PROJECT="$p" TPL_PACKAGE="$package_name" TPL_AUTHOR="$a" \
         TPL_AUTHOR_EMAIL="$ae" TPL_OWNER="$o" TPL_DESC="$d" TPL_YEAR="$y" substitute_tokens; printf x)"
  new="${new%x}"
  if [ "$new" != "$content" ]; then
    printf '%s' "$new" > "$file"
    changed=$((changed + 1))
  fi
done < <(find "$repo_root" -type d \( -name .git -o -name .jj -o -name node_modules -o -name dist -o -name coverage -o -name artifacts \) -prune -o -type f -print0)
echo "    Updated contents in $changed file(s)."

# 2) Rename files and folders whose name contains a name token. -depth processes
#    children before parents so a renamed dir doesn't invalidate paths. (The TS
#    layout ships no token-named paths today; the sweep keeps renames working if
#    you add any.)
while IFS= read -r -d '' item; do
  case "$item" in
    */.git/*|*/.jj/*|*/node_modules/*|*/dist/*|*/coverage/*|*/artifacts/*) continue ;;
  esac
  dir="$(dirname "$item")"
  base="$(basename "$item")"
  newbase="${base//__ProjectName__/$project_name}"
  newbase="${newbase//__PackageName__/$package_name}"
  if [ "$newbase" != "$base" ]; then
    mv "$item" "$dir/$newbase"
    echo "    Renamed $base -> $newbase"
  fi
done < <(find "$repo_root" -depth \( -name '*__ProjectName__*' -o -name '*__PackageName__*' \) -print0)

# 3) Activate the Claude Code shared settings.
if [ -f "$repo_root/.claude/settings.json.template" ]; then
  mv -f "$repo_root/.claude/settings.json.template" "$repo_root/.claude/settings.json"
  echo "    Activated .claude/settings.json"
fi

# 4) Remove template-only files.
rm -f "$repo_root/TEMPLATE.md" "$repo_root/docs/AGENT-INIT-GUIDE.md"
rmdir "$repo_root/docs" 2>/dev/null || true

echo ""
echo "Done. Next steps:"
echo "  1. npm install   (then commit the generated package-lock.json)"
echo "  2. npm run build && npm test"
echo "  3. npm run lint && npm run typecheck"
echo "  4. Review LICENSE (author/year) and the package metadata in package.json."
echo "  5. Publishing: add the NPM_TOKEN repo secret, or delete"
echo "     .github/workflows/release.yml and trim the publishing metadata."
echo "  6. Replace src/greeter.ts with your code and delete the sample test, then commit."

# 5) Remove both initializers unless asked to keep them.
if [ "$keep_script" -ne 1 ]; then
  rm -f "$sibling_ps1"
  rm -f "$self"
fi
