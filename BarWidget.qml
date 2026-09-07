import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar icon for the omafocus timer. Reads the shared countdown service and
// opens the config panel on click. Every bar instance is a thin observer of
// the same service singleton, so monitors never disagree about the time.
BarWidget {
  id: root

  moduleName: "omafocus"

  readonly property var service: bar && bar.shell
    ? bar.shell.serviceFor("omafocus") : null

  readonly property bool idle: !service
    || (!service.running && service.remainingSeconds === service.totalSeconds && !service.finished)

  readonly property string label: service ? service.display : ""
  readonly property string glyph: service ? service.glyph : "󰄉"
  readonly property string buttonText: root.label !== ""
    ? root.glyph + " " + root.label
    : (root.vertical ? "" : root.glyph)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function pushSettings() {
    if (service && typeof service.applySettings === "function") service.applySettings(settings)
  }

  function syncInline() {
    root.pushSettings()
    root.injectPanel()
  }

  onServiceChanged: syncInline()
  Component.onCompleted: syncInline()

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
  onSettingsChanged: syncInline()

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
    target: "omafocus"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function start(mode: string): void { if (root.service) root.service.start(mode) }
    function pause(): void { if (root.service) root.service.pause() }
    function stop(): void { if (root.service) root.service.stop() }
  }

  // Button shows the timer glyph, with the live countdown appended while a
  // session is running. Right-click toggles, middle-click resets, left opens
  // the panel.

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.buttonText
    tooltipText: root.service ? root.service.tooltip : "Omafocus"
    labelVisible: !root.vertical
    hasVisualContent: root.buttonText !== ""
    horizontalMargin: 11.75
    verticalPadding: 10.5

    onPressed: function(b) {
      if (b === Qt.RightButton) { if (root.service) root.service.toggle() }
      else if (b === Qt.MiddleButton) { if (root.service) root.service.stop() }
      else root.togglePanel()
    }
  }
}
