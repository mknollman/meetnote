# meetnote

Record a meeting from an Omarchy bar toggle; stop to get an AI summary with
action items - or in-depth training notes for learning sessions, saved as markdown in `~/Documents/meetings/`.

Built on [voxtype](https://github.com/FFXv/voxtype) meeting mode
(continuous transcription) + a local [Ollama](https://ollama.com) model for
summarization. Everything runs locally — no audio or notes leave the machine.

## What it does

- **Bar mic toggle** (next to the stoic-quote module): click once to start
  recording; click again to stop and summarize.
- Transcribes continuously with voxtype meeting mode (`--diarization ml` on
  ONNX builds for speaker labels).
- Summarizes the full transcript with `qwen2.5:7b` at a 16384-token context
  (the transcript is *much* longer than the default 4096-token context, so
  this matters — without it you only get a summary of the first few minutes).
- Writes `meeting-YYYY-MM-DD_HHMM.md` to `~/Documents/meetings/`.

## Install

```sh
git clone https://github.com/mknollman/meetnote
cd meetnote
./install/install.sh
```

Prerequisites: `voxtype` (with meeting mode), `ollama`, `jq`, `curl`,
`notify-send`, `systemctl --user`.

After install: restart the omarchy shell and the voxtype daemon.

## Usage

Left-click the mic:
- **idle** (dim) → starts recording
- **recording** (red stop) → stops and generates the summary
- **summarizing** (amber spinner) → generation in progress

Right-click the mic to pick the summary mode:
- **Meeting** — standard summary + action items
- **Training (in-depth)** — learning-focused notes: summary, key concepts,
  details & examples, action items, open questions (saved with a
  `-training` suffix on the filename)

Same from the terminal: `meetnote --mode training` (or set
`MEETNOTE_MODE=training`). The mode picked at start is remembered; a mode
given at stop overrides it for that summary.

The bar widget polls `$XDG_RUNTIME_DIR/voxtype/meeting_state` and
`meeting_summary_state`; the toggle script logs to
`~/.local/state/voxtype/meeting-toggle.log`.

## Configuration

`bin/meetnote` honors:

- `OLLAMA_HOST` — point at another machine (default `http://127.0.0.1:11434`)
- `OLLAMA_MODEL` — which model to use (default `qwen2.5:7b-ctx`)
- `MEETNOTE_MODE` — `normal` (default) or `training`

The transcription model (whisper) is configured in the installed voxtype
`config.toml` (`base.en` by default).

## Layout

- `bin/meetnote` — the start/stop + summarize toggle script (`--mode normal|training`)
- `qml/meeting-toggle.qml` — omarchy bar module (idle/recording/summarizing)
- `config/voxtype/config.toml` — voxtype: meeting mode on, 2h cap per clip
- `config/systemd/user/ollama.service` — autostart ollama
- `config/opencode/plugins/meeting-recorder.ts` — opencode `meeting_start`/
  `meeting_stop` tools (optional path into the same recording workflow)
- `install/install.sh` — installs everything above

## Notes / known issues

- Transcription runs at ~1.7x realtime after stop, so a 60-min meeting takes
  ~35 min to become fully queryable; the toggle script polls until the export
  stabilizes before summarizing.
- Raw audio is not retained (`audio_retained: false`) — only the transcript
  is stored.
- On a small CPU-only laptop, a 60-min meeting takes ~25 min to summarize
  with a 7B model. Point `OLLAMA_HOST` at a GPU box to speed that up.