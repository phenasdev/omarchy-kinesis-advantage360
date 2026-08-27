import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar button + popup for the Kinesis Advantage360. The button shows v-Drive
// state at a glance; the popup hosts the visual key-remap editor.
Panel {
  id: root
  moduleName: "io.github.phenasdev.kinesis360"
  ipcTarget: "io.github.phenasdev.kinesis360"

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
  readonly property color foreground: bar ? bar.barForeground : Color.foreground

  // The bar sizes each module slot from this root item's implicitWidth/Height
  // (see ModuleSlot in Bar.qml) — a bare Item never gets one from its
  // children on its own, so without this the button renders at zero size.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Same keyboard glyph the Logitech plugin uses for its own keyboards
  // (nf-md-keyboard_variant, U+F030C) — confirmed present in the installed
  // Nerd Font and already proven to render in this bar.
  readonly property string stateLabel: kinesis.state === "mounted" ? "󰌌 ●"
    : kinesis.state === "busy" ? "󰌌 …"
    : "󰌌"

  readonly property color stateColor: kinesis.state === "mounted" ? Color.accent
    : kinesis.state === "busy" ? root.foreground
    : Qt.darker(root.foreground, 1.4)

  readonly property string tooltip: kinesis.state === "mounted" ? "Kinesis Advantage360 — v-Drive connected"
    : kinesis.state === "busy" ? "Kinesis Advantage360 — working…"
    : "Kinesis Advantage360 — trigger the v-Drive shortcut on the keyboard"

  Service {
    id: kinesis
    pluginDir: root.pluginDir
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.stateLabel
    foreground: root.stateColor
    active: root.opened
    tooltipText: root.tooltip

    onPressed: function (mouseButton) {
      root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(1260))
    contentHeight: panel.fittedContentHeight(Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }

      Editor {
        anchors.fill: parent
        service: kinesis
        pluginDir: root.pluginDir
      }
    }
  }
}
