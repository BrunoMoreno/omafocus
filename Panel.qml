import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

// Omafocus control panel. Shows the shared countdown service's live state,
// lets the user pick a mode, run/pause/restart/reset the timer, adjust the
// three durations, and toggle the finish chime.
//
// The bar widget loads this as a popup and injects `bar`, `settings`,
// `anchorItem`, `hostWidget` and `service` onto it. Everything time-related
// lives in the service singleton, so this panel never keeps its own copy of
// the countdown.
Panel {
  id: root
  moduleName: "omafocus"
  ipcTarget: "omafocus"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property var service: null

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ------------------------------------------------------------- cursor model
  readonly property int idxMode: 0
  readonly property int idxStart: 1
  readonly property int idxRestart: 2
  readonly property int idxReset: 3
  readonly property int idxFocus: 4
  readonly property int idxShort: 5
  readonly property int idxLong: 6
  readonly property int idxSound: 7

  property int cursorIndex: 0
  property bool cursorActive: false

  function itemCount() { return 8 }

  function moveCursor(delta) {
    root.cursorActive = true
    root.cursorIndex = Math.max(0, Math.min(root.itemCount() - 1, root.cursorIndex + delta))
  }

  function modes() { return ["focus", "short-break", "long-break"] }

  function modeGroupIndex() {
    var idx = root.modes().indexOf(root.modeValue)
    return idx < 0 ? 0 : idx
  }

  function focusSpin(spin) {
    if (!spin) return
    spin.forceActiveFocus()
    var input = spin.contentItem
    if (input && typeof input.selectAll === "function")
      Qt.callLater(function() { input.selectAll() })
  }

  function focusFieldFromCursor() { root.focusSpin(focusField.field) }
  function focusShortFromCursor() { root.focusSpin(shortField.field) }
  function focusLongFromCursor() { root.focusSpin(longField.field) }

  function nextMode(dir) {
    var order = root.modes()
    var idx = order.indexOf(root.modeValue)
    if (idx < 0) idx = 0
    return order[(idx + (dir > 0 ? 1 : -1) + order.length) % order.length]
  }

  function cycleMode(dir) {
    if (!root.service) return
    var next = root.nextMode(dir)
    if (next !== root.modeValue) root.service.setMode(next)
  }

  function activateCursor() {
    switch (root.cursorIndex) {
      case root.idxMode: root.cycleMode(1); return
      case root.idxStart: root.primaryAction(); return
      case root.idxRestart: root.restartTimer(); return
      case root.idxReset: root.stopTimer(); return
      case root.idxFocus: root.focusFieldFromCursor(); return
      case root.idxShort: root.focusShortFromCursor(); return
      case root.idxLong: root.focusLongFromCursor(); return
      case root.idxSound: root.toggleSound(); return
    }
  }

  // ------------------------------------------------------------- live state
  readonly property bool timerRunning: root.service ? root.service.running === true : false
  readonly property bool timerFinished: root.service ? root.service.finished === true : false
  readonly property int totalSeconds: root.service ? Math.max(1, Number(root.service.totalSeconds) || 1) : 1
  readonly property int remainingSeconds: root.service ? Math.max(0, Number(root.service.remainingSeconds) || 0) : 0

  readonly property string modeValue: root.service && root.service.mode ? String(root.service.mode) : "focus"
  readonly property bool modeFocus: root.modeValue === "focus"
  readonly property string modeTitle: root.modeFocus ? "Focus" : (root.modeValue === "short-break" ? "Short break" : "Long break")

  readonly property string statusChip: {
    if (root.timerFinished) return "DONE"
    if (root.timerRunning) return "RUNNING"
    return root.remainingSeconds < root.totalSeconds ? "PAUSED" : "READY"
  }

  readonly property real timeProgress: root.totalSeconds > 0
    ? Math.max(0, Math.min(1, (root.totalSeconds - root.remainingSeconds) / root.totalSeconds))
    : 0

  readonly property string heroTime: root.service ? root.service.formattedRemaining() : "25:00"

  // ------------------------------------------------------------- settings
  function settingNum(key, fallback) {
    var v = root.service && root.service.settings ? root.service.settings[key] : undefined
    var n = Number(v)
    return isNaN(n) ? fallback : n
  }

  readonly property int focusMinutes: root.settingNum("focusMinutes", 25)
  readonly property int shortBreakMinutes: root.settingNum("shortBreakMinutes", 5)
  readonly property int longBreakMinutes: root.settingNum("longBreakMinutes", 15)
  readonly property bool soundEnabled: root.service && root.service.settings
    ? root.service.settings.soundEnabled !== false : true

  // ------------------------------------------------------------- actions
  function primaryAction() {
    if (!root.service) return
    if (root.service.running) root.service.pause()
    else if (root.service.finished) root.service.restart()
    else root.service.start(root.service.mode)
  }

  function restartTimer() {
    if (root.service) root.service.restart()
  }

  function stopTimer() {
    if (root.service) root.service.stop()
  }

  function setDuration(key, value) {
    if (!root.service) return
    var m = Math.max(1, Math.round(Number(value) || 1))
    root.service.persistSetting(key, m)
    // Re-arm the running-read timer so the new duration shows immediately.
    if (!root.service.running) root.service.setMode(root.service.mode)
  }

  function toggleSound() {
    if (root.service) root.service.setSoundEnabled(!root.soundEnabled)
  }

  // ------------------------------------------------------------- lifecycle
  function open() {
    root.cursorIndex = 0
    root.cursorActive = false
    root.controller.show()
  }

  function openFromHotkey() { root.open() }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    root.opened ? root.close() : root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  onOpenedChanged: {
    if (root.opened) {
      root.cursorIndex = 0
      root.cursorActive = false
    }
  }

  readonly property bool keyCatcherBlocked: (focusField && focusField.field && focusField.field.activeFocus)
    || (shortField && shortField.field && shortField.field.activeFocus)
    || (longField && longField.field && longField.field.activeFocus)

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340), Style.space(420))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(580))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.keyCatcherBlocked
      onMoveRequested: function(dx, dy) {
        if (root.cursorActive && root.cursorIndex === root.idxMode) {
          if (dx !== 0) { root.cycleMode(dx); return }
          if (dy !== 0) root.moveCursor(dy)
          return
        }
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: root.activateCursor()
      onTextKey: function(t) {
        if (t === "f" || t === "F") { if (root.service) root.service.setMode("focus") }
        else if (t === "s" || t === "S") { if (root.service) root.service.setMode("short-break") }
        else if (t === "l" || t === "L") { if (root.service) root.service.setMode("long-break") }
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Column {
          id: contentColumn
          width: scrollArea.availableWidth
          spacing: Style.space(12)

          // ---- Hero: live countdown with a progress rail.
          Item {
            width: parent.width
            implicitHeight: heroHead.implicitHeight + Style.space(10) + Style.space(6)

            Row {
              id: heroHead
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              spacing: Style.space(16)

              Text {
                id: heroGlyph
                text: root.service ? root.service.glyph : "󰄉"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display + Style.space(6)
              }

              Item {
                width: parent.width - heroGlyph.width - parent.spacing
                height: heroGlyph.implicitHeight

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  spacing: Style.space(2)

                  Row {
                    width: parent.width

                    Text {
                      textFormat: Text.PlainText
                      text: root.modeTitle.toUpperCase()
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      font.letterSpacing: 1.2
                      elide: Text.ElideRight
                    }

                    Text {
                      textFormat: Text.PlainText
                      anchors.right: parent.right
                      text: root.statusChip
                      color: root.timerFinished ? root.urgent : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      font.letterSpacing: 1
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: root.heroTime
                    color: root.timerFinished ? root.urgent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.display
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    textFormat: Text.PlainText
                    visible: root.timerFinished
                    width: parent.width
                    text: "Time's up — take a break."
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }
              }
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: heroHead.bottom
              anchors.topMargin: Style.space(10)
              height: Style.space(6)
              radius: height / 2
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

              Rectangle {
                width: Math.round(parent.width * root.timeProgress)
                height: parent.height
                radius: parent.radius
                color: Style.selectedStateColor(root.foreground, Color.accent)

                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---- Mode picker.
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "MODE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            ButtonGroup {
              width: parent.width
              focusable: false
              options: [
                { value: "focus", label: "Focus" },
                { value: "short-break", label: "Short" },
                { value: "long-break", label: "Long" }
              ]
              value: root.modeValue
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              cursorIndex: (root.cursorActive && root.cursorIndex === root.idxMode)
                ? root.modeGroupIndex() : -1
              onChanged: function(v) {
                if (root.service && v !== root.modeValue) root.service.setMode(v)
              }
              onHovered: function(index, h) {
                if (h) { root.cursorActive = true; root.cursorIndex = root.idxMode }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---- Transport controls.
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "TIMER"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(10)

              Button {
                width: (parent.width - parent.spacing * 2) / 3
                text: root.timerRunning ? "Pause" : (root.timerFinished ? "Restart" : "Start")
                iconText: root.timerRunning ? "󰏤" : (root.timerFinished ? "󰑓" : "󰐊")
                selected: true
                hasCursor: root.cursorActive && root.cursorIndex === root.idxStart
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.body
                onHovered: function(h) {
                  if (h) { root.cursorActive = true; root.cursorIndex = root.idxStart }
                }
                onClicked: root.primaryAction()
              }

              Button {
                width: (parent.width - parent.spacing * 2) / 3
                text: "Restart"
                iconText: "󰑓"
                bordered: true
                hasCursor: root.cursorActive && root.cursorIndex === root.idxRestart
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.body
                onHovered: function(h) {
                  if (h) { root.cursorActive = true; root.cursorIndex = root.idxRestart }
                }
                onClicked: root.restartTimer()
              }

              Button {
                width: (parent.width - parent.spacing * 2) / 3
                text: "Reset"
                bordered: true
                hasCursor: root.cursorActive && root.cursorIndex === root.idxReset
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.body
                onHovered: function(h) {
                  if (h) { root.cursorActive = true; root.cursorIndex = root.idxReset }
                }
                onClicked: root.stopTimer()
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---- Durations.
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "DURATIONS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(10)

              NumberField {
                id: focusField
                width: (parent.width - parent.spacing * 2) / 3
                fieldWidth: width
                label: "Focus"
                value: root.focusMinutes
                from: 1
                to: 180
                stepSize: 1
                hasCursor: root.cursorActive && root.cursorIndex === root.idxFocus
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                onModified: function(v) { root.setDuration("focusMinutes", v) }
                onHovered: function(h) {
                  if (h) { root.cursorActive = true; root.cursorIndex = root.idxFocus }
                }
              }

              NumberField {
                id: shortField
                width: (parent.width - parent.spacing * 2) / 3
                fieldWidth: width
                label: "Short"
                value: root.shortBreakMinutes
                from: 1
                to: 60
                stepSize: 1
                hasCursor: root.cursorActive && root.cursorIndex === root.idxShort
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                onModified: function(v) { root.setDuration("shortBreakMinutes", v) }
                onHovered: function(h) {
                  if (h) { root.cursorActive = true; root.cursorIndex = root.idxShort }
                }
              }

              NumberField {
                id: longField
                width: (parent.width - parent.spacing * 2) / 3
                fieldWidth: width
                label: "Long"
                value: root.longBreakMinutes
                from: 1
                to: 120
                stepSize: 1
                hasCursor: root.cursorActive && root.cursorIndex === root.idxLong
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                onModified: function(v) { root.setDuration("longBreakMinutes", v) }
                onHovered: function(h) {
                  if (h) { root.cursorActive = true; root.cursorIndex = root.idxLong }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---- Finish behaviour.
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "NOTIFICATION"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Toggle {
              width: parent.width
              label: "Sound on finish"
              description: "Play a chime when a session ends"
              checked: root.soundEnabled
              hasCursor: root.cursorActive && root.cursorIndex === root.idxSound
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              onHovered: function(h) {
                if (h) { root.cursorActive = true; root.cursorIndex = root.idxSound }
              }
              onClicked: root.toggleSound()
            }
          }
        }
      }
    }
  }
}