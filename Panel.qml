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
  // Nerd Font and already proven to render in this bar. A single glyph only:
  // BarIconButton optically centers exactly one glyph in a fixed-size slot,
  // so state is conveyed by color alone — appending "●"/"…" here (as an
  // earlier version did) skews that centering and throws off the bar's
  // open-panel indicator line, which is centered on the fixed slot too.
  readonly property string stateGlyph: "󰌌"

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

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.stateGlyph
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
    // Fit exactly to the Editor's real content size (see Editor.qml's
    // implicitWidth/Height forwarding) instead of a guessed fixed size —
    // the cap is just a safety ceiling for an unexpectedly tall category list.
    contentWidth: panel.fittedContentWidth(editor.implicitWidth)
    contentHeight: panel.fittedContentHeight(editor.implicitHeight, Style.space(900))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }

      Editor {
        id: editor
        anchors.fill: parent
        service: kinesis
        pluginDir: root.pluginDir
      }
    }
  }
}
