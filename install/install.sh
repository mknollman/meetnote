#!/usr/bin/env bash
# meetnote — install the meeting recorder + summarizer on an Omarchy box.
# Click the bar mic to start/stop; a markdown summary lands in
# ~/Documents/meetings/. Requires voxtype with meeting mode + ollama.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
BIN_DIR="$HOME/.local/bin"
BAR_MODULES="$HOME/.config/omarchy/bar/modules"
VOXTYPE_CFG="$HOME/.config/voxtype"
SERVICE_DIR="$HOME/.config/systemd/user"
OPENCODE_PLUGINS="$HOME/.config/opencode/plugins"
MEETINGS_DIR="$HOME/Documents/meetings"
SUMMARY_MODEL="qwen2.5:7b-ctx"

echo "==> meetnote installer"

for cmd in python3 ollama; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "!! $cmd is required but not installed (pacman -S $cmd)" >&2
    exit 1
  }
done

for d in "$BIN_DIR" "$BAR_MODULES" "$VOXTYPE_CFG" "$SERVICE_DIR" "$OPENCODE_PLUGINS" "$MEETINGS_DIR"; do
  mkdir -p "$d"
done

echo "==> Installing bin/meetnote"
install -m 0755 "$REPO_DIR/bin/meetnote" "$BIN_DIR/meetnote"

echo "==> Installing bar module"
install -m 0644 "$REPO_DIR/qml/meeting-toggle.qml" "$BAR_MODULES/meeting-toggle.qml"

echo "==> Installing voxtype config"
if [[ -f "$VOXTYPE_CFG/config.toml" ]]; then
  cp -a "$VOXTYPE_CFG/config.toml" "$VOXTYPE_CFG/config.toml.bak.$(date +%s)"
fi
install -m 0644 "$REPO_DIR/config/voxtype/config.toml" "$VOXTYPE_CFG/config.toml"

echo "==> Installing ollama user service"
install -m 0644 "$REPO_DIR/config/systemd/user/ollama.service" "$SERVICE_DIR/ollama.service"
systemctl --user daemon-reload
systemctl --user enable --now ollama 2>/dev/null || true

echo "==> Installing opencode plugin"
install -m 0644 "$REPO_DIR/config/opencode/plugins/meeting-recorder.ts" "$OPENCODE_PLUGINS/meeting-recorder.ts"

echo "==> Wiring the meeting-toggle bar module into shell.json"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
if [[ -f "$SHELL_JSON" ]]; then
  cp -a "$SHELL_JSON" "$SHELL_JSON.bak.$(date +%s)"
  python3 - "$SHELL_JSON" <<'PY'
import json, os, sys

path = sys.argv[1]
entry = {
    "id": "meeting-toggle",
    "type": "qml",
    "source": "~/.config/omarchy/bar/modules/meeting-toggle.qml",
}

with open(path) as f:
    cfg = json.load(f)

center = cfg.get("bar", {}).get("layout", {}).get("center")
if center is None:
    sys.exit("!! no bar.layout.center in shell.json — add meeting-toggle manually")

if any(w.get("id") == "meeting-toggle" for w in center):
    print("   meeting-toggle already present in shell.json")
    sys.exit(0)

ids = [w.get("id") for w in center]
if "stoic-quote" in ids:
    center.insert(ids.index("stoic-quote") + 1, entry)
else:
    center.append(entry)

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
print("   wired meeting-toggle into shell.json")
PY
else
  echo "!! $SHELL_JSON not found — add the meeting-toggle entry manually." >&2
fi

echo "==> Ensuring summary model ($SUMMARY_MODEL) exists"
if ! ollama list 2>/dev/null | grep -q "^$SUMMARY_MODEL"; then
  ollama pull qwen2.5:7b
  MODELFILE="$(mktemp)"
  printf 'FROM qwen2.5:7b\nPARAMETER num_ctx 16384\n' > "$MODELFILE"
  ollama create "$SUMMARY_MODEL" -f "$MODELFILE"
  rm -f "$MODELFILE"
else
  echo "   $SUMMARY_MODEL already present"
fi

echo
echo "==> Done."
echo "Next steps:"
echo "  1. omarchy restart shell        # show the mic in the bar"
echo "  2. Restart voxtype daemon      # pick up meeting mode:"
echo "     systemctl --user restart voxtype"
echo "  3. Click the mic in the bar to start/stop recording."
echo "  4. Summaries land in $MEETINGS_DIR"
echo "     (OLLAMA_HOST/MODEL overrides are honored by bin/meetnote.)"
