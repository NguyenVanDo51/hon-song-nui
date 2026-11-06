#!/usr/bin/env bash
# installs the git pre-commit hook: tools/lint.sh --staged (skip once: git commit --no-verify)
cd "$(dirname "$0")/.."
hook=$(git rev-parse --git-path hooks)/pre-commit
printf '#!/usr/bin/env bash\nexec "$(git rev-parse --show-toplevel)/tools/lint.sh" --staged\n' > "$hook"
chmod +x "$hook"
echo "installed $hook"
