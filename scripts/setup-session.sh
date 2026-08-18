#!/usr/bin/env bash
set -euo pipefail

# Session setup script for claude/repo-setup-features-zsmukh
# Re-links skills and starts services that don't persist across container sessions.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/.agents/skills"
SKILLS_DST="$REPO_ROOT/.claude/skills"

echo "=== Claude Code Session Setup ==="
echo ""

# --- 1. Re-link skills ---
echo "[1/4] Re-linking skills..."
mkdir -p "$SKILLS_DST"
linked=0
for skill_dir in "$SKILLS_SRC"/*/; do
  skill_name="$(basename "$skill_dir")"
  if [ ! -L "$SKILLS_DST/$skill_name" ]; then
    ln -sf "$SKILLS_SRC/$skill_name" "$SKILLS_DST/$skill_name"
    ((linked++))
  fi
done
total=$(ls -d "$SKILLS_SRC"/*/ 2>/dev/null | wc -l)
echo "  $linked new symlinks created ($total skills total)"

# --- 2. Install & start OmniRoute ---
echo "[2/4] OmniRoute AI gateway..."
if command -v omniroute &>/dev/null; then
  echo "  Already installed: $(omniroute --version 2>/dev/null || echo 'unknown version')"
else
  echo "  Installing omniroute globally..."
  npm install -g omniroute
fi
if ! curl -sf http://127.0.0.1:20128/v1/models &>/dev/null; then
  echo "  Starting OmniRoute on port 20128..."
  nohup omniroute &>/tmp/omniroute.log &
  sleep 3
  if curl -sf http://127.0.0.1:20128/v1/models &>/dev/null; then
    echo "  OmniRoute running at http://127.0.0.1:20128/v1"
  else
    echo "  WARNING: OmniRoute failed to start (check /tmp/omniroute.log)"
  fi
else
  echo "  Already running at http://127.0.0.1:20128/v1"
fi

# --- 3. Install & start claude-mem ---
echo "[3/4] claude-mem persistent memory..."
if command -v claude-mem &>/dev/null || npx claude-mem --version &>/dev/null 2>&1; then
  echo "  Already installed"
else
  echo "  Installing claude-mem..."
  npx claude-mem install 2>/dev/null || echo "  WARNING: claude-mem install failed"
fi
if ! curl -sf http://127.0.0.1:37700 &>/dev/null; then
  echo "  Starting claude-mem worker..."
  npx claude-mem start &>/dev/null &
  sleep 2
  if curl -sf http://127.0.0.1:37700 &>/dev/null; then
    echo "  claude-mem running at http://127.0.0.1:37700"
  else
    echo "  WARNING: claude-mem worker failed to start"
  fi
else
  echo "  Already running at http://127.0.0.1:37700"
fi

# --- 4. Install headroom ---
echo "[4/4] headroom token compression..."
if python3 -c "import headroom" 2>/dev/null; then
  echo "  Python package already installed"
else
  echo "  Installing headroom Python package..."
  pip install --quiet --ignore-installed "headroom-ai[all]" 2>/dev/null || \
    echo "  WARNING: headroom pip install failed"
fi
if npm list -g headroom-ai &>/dev/null 2>&1; then
  echo "  npm package already installed"
else
  echo "  Installing headroom npm package..."
  npm install -g headroom-ai 2>/dev/null || \
    echo "  WARNING: headroom npm install failed"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Active services:"
curl -sf http://127.0.0.1:20128/v1/models &>/dev/null && \
  echo "  OmniRoute:  http://127.0.0.1:20128/v1" || \
  echo "  OmniRoute:  not running"
curl -sf http://127.0.0.1:37700 &>/dev/null && \
  echo "  claude-mem: http://127.0.0.1:37700" || \
  echo "  claude-mem: not running"
echo ""
echo "Skills: $total linked in .claude/skills/"
echo ""
echo "Note: On a local machine, most free providers in OmniRoute will work."
echo "      In a cloud container, external AI calls may be blocked by the proxy."
