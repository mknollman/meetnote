import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Meeting recorder toggle for the bar. Click to start recording a meeting,
// click again to stop and generate a markdown summary (Summary + Action
// Items) saved to ~/Documents/meetings/. Custom bar module, loaded as:
// `type: "qml"` from ~/.config/omarchy/bar/modules/meeting-toggle.qml.
//
// States:
//   idle          dim record glyph
//   recording     red stop glyph (daemon's meeting_state == "recording")
//   summarizing   amber spinning glyph (meeting_summary_state == "working")
BarWidget {
  id: root
  moduleName: "meeting-toggle"

  property bool recording: false
  property bool summarizing: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // mdi-record (U+F0065) when idle, mdi-stop (U+F003C) when recording.
  readonly property string idleGlyph: "\uDB80\uDC65"
  readonly property string activeGlyph: "\uDB80\uDC3C"

  readonly property string colorIdle: Qt.darker(root.foreground, 1.15)
  readonly property string colorRecording: "#e06c75"
  readonly property string colorSummarizing: "#d19a66"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function runProc(p, cmd) {
    p.command = cmd
    p.running = false
    p.running = true
  }

  function poll() {
    runProc(statusProc, ["bash", "-lc", 'ms="$XDG_RUNTIME_DIR/voxtype/meeting_state"; ss="$XDG_RUNTIME_DIR/voxtype/meeting_summary_state"; rec=IDLE; sum=IDLE; grep -q "^recording$" "$ms" 2>/dev/null && rec=RUN; grep -q "^working$" "$ss" 2>/dev/null && sum=WORK; echo "$rec $sum"'])
  }

  function toggle() {
    if (toggleProc.running) return
    runProc(toggleProc, ["bash", "-lc", 'PATH="$HOME/.local/bin:$PATH"; command -v meetnote >/dev/null && meetnote || notify-send -a voxtype "meetnote missing" "Run the meetnote installer"'])
    // Recording state flips immediately so the button responds; poll will
    // correct itself once the toggle script finishes.
    root.recording = !root.recording
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parts = String(text).trim().split(/\s+/)
        root.recording = parts[0] === "RUN"
        root.summarizing = parts[1] === "WORK"
        tickTimer.restart()
      }
    }
  }

  // Re-check state periodically so the button reflects reality even if the
  // meeting was started/stopped elsewhere.
  Timer {
    id: tickTimer
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.poll()
  }

  Process {
    id: toggleProc
    running: false
    onRunningChanged: {
      if (!running) root.poll()
    }
  }

  Component.onCompleted: root.poll()

  BarIconButton {
    id: button
    bar: root.bar
    text: root.recording ? root.activeGlyph : root.idleGlyph
    active: root.recording || root.summarizing
    useActiveColor: root.recording || root.summarizing
    activeColor: root.summarizing ? root.colorSummarizing : root.colorRecording
    foreground: root.recording ? root.colorRecording
              : root.summarizing ? root.colorSummarizing : root.colorIdle
    tooltipText: root.summarizing ? "Generating meeting summary…"
               : (root.recording ? "Stop meeting and summarize" : "Start meeting recording")
    // Slow spin while summarizing to make it visually distinct.
    NumberAnimation on textRotation {
      running: root.summarizing
      from: 0
      to: 360
      duration: 1600
      loops: Animation.Infinite
    }
    onPressed: function(btn) {
      if (btn === Qt.LeftButton) root.toggle()
    }
  }
}