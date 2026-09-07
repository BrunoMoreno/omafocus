import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Headless omafocus countdown shared by every bar instance. One timer runs
// here, not per monitor, so multiple bar widgets and the panel all observe
// the same remaining time without drifting apart.
//
// The shell injects `shell`, `manifest` and `omarchyPath`. The bar widget
// pushes `settings` (from its shell.json entry) onto us via applySettings.
Item {
  id: root

  visible: false
  width: 0
  height: 0

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "omafocus"
  // Writable so the shell's injected value (which is authoritative) wins over
  // the env fallback.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/lib/omarchy"

  final property string modeFocusKey: "focus"
  final property string modeShortKey: "short-break"
  final property string modeLongKey: "long-break"

  readonly property var defaultSettingValues: ({
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    defaultMode: "focus",
    soundEnabled: true
  })
  property var settings: defaultSettingValues

  function applySettings(values) {
    var next = ({})
    for (var key in defaultSettingValues) next[key] = defaultSettingValues[key]
    var source = values || ({})
    for (var name in source) {
      if (source[name] === undefined || source[name] === null) continue
      next[name] = source[name]
    }
    if (JSON.stringify(next) !== JSON.stringify(settings)) settings = next
  }

  function persistSetting(name, value) {
    var next = ({})
    for (var key in settings) if (key !== "id") next[key] = settings[key]
    next[name] = value
    applySettings(next)
    var entry = ({ id: pluginId })
    for (var field in next) entry[field] = next[field]
    if (shell && typeof shell.updateEntryInline === "function")
      shell.updateEntryInline(pluginId, entry)
  }

  function setSoundEnabled(value) {
    persistSetting("soundEnabled", value === true)
  }

  // ------------------------------------------------------------- duration
  function modeMinutes(mode) {
    var m = String(mode || "")
    if (m === modeShortKey) return clampMin(Number(settings.shortBreakMinutes || 5), 1, 60)
    if (m === modeLongKey) return clampMin(Number(settings.longBreakMinutes || 15), 1, 120)
    return clampMin(Number(settings.focusMinutes || 25), 1, 180)
  }

  function defaultMode() {
    var m = String(settings.defaultMode || "focus")
    if (m !== modeShortKey && m !== modeLongKey) return modeFocusKey
    return m
  }

  function clampMin(value, lo, hi) {
    return Math.max(lo, Math.min(hi, value))
  }

  // ------------------------------------------------------------- state
  property string mode: defaultMode()
  property int totalSeconds: modeMinutes(mode) * 60
  property int remainingSeconds: totalSeconds
  property bool running: false
  property bool finished: false

  function setMode(nextMode) {
    var m = String(nextMode || modeFocusKey)
    if (m !== modeShortKey && m !== modeLongKey) m = modeFocusKey
    timer.stop()
    running = false
    finished = false
    mode = m
    totalSeconds = modeMinutes(m) * 60
    remainingSeconds = totalSeconds
    emitState()
  }

  function start(nextMode) {
    setMode(nextMode)
    running = true
    timer.start()
    emitState()
  }

  function pause() {
    if (!running) return
    running = false
    timer.stop()
    emitState()
  }

  function resume() {
    if (running) return
    if (remainingSeconds <= 0) { root.setMode(mode); running = true } else { running = true }
    timer.start()
    emitState()
  }

  function toggle() {
    running ? pause() : resume()
  }

  function restart() {
    setMode(mode)
    running = true
    timer.start()
    emitState()
  }

  function stop() {
    timer.stop()
    running = false
    finished = false
    remainingSeconds = totalSeconds
    emitState()
  }

  // ------------------------------------------------------------- display
  readonly property string modeLabel: {
    if (mode === modeShortKey) return "Short break"
    if (mode === modeLongKey) return "Long break"
    return "Focus"
  }

  readonly property string glyph: {
    if (mode === modeShortKey) return "󰥔"
    if (mode === modeLongKey) return "󰥔"
    return "󰄉"
  }

  function formattedRemaining() {
    var s = Math.max(0, remainingSeconds)
    var m = Math.floor(s / 60)
    var r = s % 60
    return (m < 10 ? "0" + m : m) + ":" + (r < 10 ? "0" + r : r)
  }

  readonly property string display: running || finished || remainingSeconds !== totalSeconds
    ? formattedRemaining() : ""

  readonly property string tooltip: {
    if (remainingSeconds === totalSeconds && !running) return "Omafocus · Ready"
    var tail = finished ? " — time's up!" : ""
    return "Omafocus · " + modeLabel + " · " + formattedRemaining() + tail
  }

  // ------------------------------------------------------------- ticking
  Timer {
    id: timer
    interval: 1000
    repeat: true
    onTriggered: root.tick()
  }

  function tick() {
    if (!running) { timer.stop(); return }
    if (remainingSeconds > 0) remainingSeconds -= 1
    if (remainingSeconds <= 0) {
      remainingSeconds = 0
      running = false
      timer.stop()
      finished = true
      onCompleted()
    }
    emitState()
  }

  signal statusChanged()
  function emitState() {
    var i = _epoch + 1
    _epoch = i
    statusChanged()
  }
  property int _epoch: 0

  // ------------------------------------------------------------- finish
  function onCompleted() {
    notifyComplete()
    if (String(settings.soundEnabled) !== "false") playChime()
  }

  function notifyComplete() {
    var glyph = root.glyph
    var args = ["--app-name", "Omafocus", "-g", glyph, "-u", "normal",
      "Omafocus finished", root.modeLabel + " is over. Take a break!"]
    if (omarchyPath !== "") {
      Quickshell.execDetached([omarchyPath + "/bin/omarchy-notification-send"].concat(args))
    } else {
      Quickshell.execDetached(["omarchy-notification-send"].concat(args))
    }
  }

  function playChime() {
    // Ship a custom chime next to the plugin; fall back to the stock
    // freedesktop alarm chime if the asset is not present.
    var pluginSound = Quickshell.env("HOME")
      + "/.config/omarchy/plugins/omafocus/assets/timer-end.oga"
    var stock = "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    // A tiny wrapper: prefer the shipped asset, else the stock chime.
    var sh = "if [ -f '" + pluginSound + "' ]; then exec paplay '" + pluginSound
      + "'; elif [ -f '" + stock + "' ]; then exec paplay '" + stock
      + "'; else exec canberra-gtk-play -i complete; fi"
    Quickshell.execDetached(["bash", "-c", sh])
  }
}
