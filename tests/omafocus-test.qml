import QtQuick
import Quickshell
import qs.Commons

Item {
  id: probe

  property var failures: []
  function check(name, cond) {
    if (!cond) failures.push(name)
    console.log("  [" + (cond ? "PASS" : "FAIL") + "] " + name)
  }
  function done() {
    console.log(failures.length === 0 ? "ALL TESTS PASSED" : "FAILURES: " + failures.join(", "))
    Qt.quit()
  }

  property string pluginDir: Quickshell.env("OMAFOCUS_DIR") || "/home/bruno/Codes/pomodoro"

  // Fake shell that records entry inline writes.
  property var writtenEntries: ({})
  property var fakeShell: Qt.createQmlObject('import QtQuick; QtObject { property var writer: null; function updateEntryInline(id, entry) { if (writer) writer(id, entry) } }', probe, "fakeShell")
  property var service: null

  Component.onCompleted: {
    probe.writtenEntries = {}
    probe.fakeShell.writer = function(id, entry) {
      probe.writtenEntries[id] = JSON.parse(JSON.stringify(entry))
    }

    var comp = Qt.createComponent("file://" + probe.pluginDir + "/Service.qml")
    service = comp.createObject(probe)
    service.shell = probe.fakeShell
    service.manifest = { id: "omafocus" }
    service.omarchyPath = "/nonexistent"   // keep notifications from spawning real binaries

    // defaults
    check("default mode is focus", service.mode === "focus")
    check("default focus duration 25m", service.totalSeconds === 1500)
    check("display empty when idle", service.display === "")
    check("tooltip says ready", service.tooltip.indexOf("Ready") !== -1)

    // applySettings merges + hands values into duration
    service.applySettings({ focusMinutes: 45, soundEnabled: false })
    check("settings applied", service.settings.focusMinutes === 45 && service.settings.soundEnabled === false)

    // state machine
    service.start("short-break")
    check("start short-break sets mode+minutes", service.mode === "short-break"
      && service.totalSeconds === 300 && service.running === true)
    check("display shows 05:00", service.display === "05:00")
    service.tick()
    service.tick()
    service.tick()
    check("tick decreases remaining", service.remainingSeconds === 297)
    check("display shows 04:57", service.display === "04:57")
    check("label short break", service.modeLabel === "Short break")

    service.pause()
    check("pause stops", service.running === false)
    service.resume()
    check("resume restarts", service.running === true)
    service.stop()
    check("stop resets", !service.running && service.remainingSeconds === service.totalSeconds && !service.finished)

    service.setMode("long-break")
    check("setMode long-break", service.mode === "long-break" && service.totalSeconds === service.modeMinutes("long-break") * 60)

    // persist writes through shell and re-arms durations
    service.persistSetting("focusMinutes", 30)
    check("persistSetting applied", service.settings.focusMinutes === 30)
    check("persistSetting wrote entry", probe.writtenEntries["omafocus"]
      && probe.writtenEntries["omafocus"].focusMinutes === 30)
    check("persistSetting writes id", probe.writtenEntries["omafocus"].id === "omafocus")

    service.setMode("focus")
    check("re-arm uses new duration", service.totalSeconds === 1800 && service.remainingSeconds === 1800)

    // completion path: set 1 minute, run 60 ticks
    service.persistSetting("focusMinutes", 1)
    service.setMode("focus")
    service.start("focus")
    var i
    for (i = 0; i < 60; i++) service.tick()
    check("finishes after duration", !service.running && service.finished && service.remainingSeconds === 0)
    check("finished display", service.display === "00:00")
    check("tooltip mentions time's up", service.tooltip.indexOf("time's up") !== -1)

    // sound toggle
    service.setSoundEnabled(true)
    check("setSoundEnabled true", service.settings.soundEnabled === true)

    done()
  }
}