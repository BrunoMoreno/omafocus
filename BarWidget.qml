import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar icon for the pomodoro timer. Reads the shared countdown service and
// opens the config panel on click. Every bar instance is a thin observer of
// the same service singleton, so monitors never disagree about the time.
BarWidget {
  id: root

  moduleName: "pomodoro"

  readonly property var service: bar && bar.shell
    ? bar.shell.serviceFor("pomodoro") : null

  readonly property bool idle: !service
    || (!service.running && service.remainingSeconds === service.totalSeconds && !service.finished)

  readonly property string label: service ? service.display : ""
  readonly property string glyph: service ? service.glyph : "󰄉"

  function pushSettings() {
    if (service && typeof service.applySettings === "function") service.applySettings(settings)
  }

  onSettingsChanged: pushSettings()
  onServiceChanged: pushSettings()
  Component.onCompleted: pushSettings()

  // ---- Panel popup. Shape contract for shell.summon/hide/toggle routing:
  //      the bar expects open/close/opened on the bar-widget root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property var barIdentity: root

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = root.service
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "pomodoro"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function start(mode: string): void { if (root.service) root.service.start(mode) }
    function pause(): void { if (root.service) root.service.pause() }
    function stop(): void { if (root.service) root.service.stop() }
  }

  // The button shows a small corner dot while a countdown is active, like the
  // other indicators — but keeps the live countdown text on the label itself.

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.idle ? "" : root.label
    tooltipText: root.service ? root.service.tooltip : "Pomodoro"
    labelVisible: !root.vertical
    hasVisualContent: root.label !== "" || !root.vertical
    horizontalMargin: 8.75
    verticalPadding: 8.75

    iconComponent: Component {
      Item {
        OpticalGlyph {
          anchors.fill: parent
          text: root.glyph
          fontFamily: button.fontFamily
          fontSize: button.fontSize
          color: button.foreground
        }
      }
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) { if (root.service) root.service.toggle() }
      else if (b === Qt.MiddleButton) { if (root.service) root.service.stop() }
      else root.togglePanel()
    }
  }
}
