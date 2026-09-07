import QtQuick
import Quickshell

Item {
  Component.onCompleted: {
    function probe(label, url) {
      var comp = Qt.createComponent("file://" + url)
      var status = comp.status === Component.Ready ? "READY" : ("ERROR: " + comp.errorString())
      console.log("[" + label + "] " + status)
    }
    var dir = Quickshell.env("OMAFOCUS_DIR") || "/home/bruno/Codes/pomodoro"
    probe("Service", dir + "/Service.qml")
    probe("BarWidget", dir + "/BarWidget.qml")
    probe("Panel", dir + "/Panel.qml")
    Qt.quit()
  }
}