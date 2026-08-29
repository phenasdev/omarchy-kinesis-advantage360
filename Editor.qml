import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

// Visual key-remap editor: profile + layer tabs, the split keyboard drawn
// from data/position_tokens.json, and a searchable action picker (from
// data/action_tokens.json) for whichever key was clicked. Lives inside the
// KeyboardPanel popup declared in Panel.qml; not a manifest entry point.
Item {
  id: root

  property var service: null
  property string pluginDir: ""

  readonly property color foreground: Color.popups.text
  readonly property color accent: Color.accent
  readonly property int cell: Style.space(44)
  readonly property int gap: Style.space(3)

  FileView { id: posFile; path: root.pluginDir + "/data/position_tokens.json"; blockLoading: true }
  FileView { id: actFile; path: root.pluginDir + "/data/action_tokens.json"; blockLoading: true }
  readonly property var posData: JSON.parse(posFile.text())
  readonly property var actData: JSON.parse(actFile.text())

  readonly property var categories: actData.categories
  property string selectedCategoryId: categories.length > 0 ? categories[0].id : ""
  property string categoryQuery: ""

  // Tokens for the active category, filtered by the search field. With an
  // empty query, only the curated "common" subset shows (SmartSet-style
  // browsing); typing reaches the full dictionary, including the long tail
  // of numeric-keypad/international tokens.
  function categoryTokens(catId, query) {
    var out = []
    var tokens = root.actData.tokens
    var q = (query || "").toLowerCase()
    for (var k in tokens) {
      var t = tokens[k]
      if (t.category !== catId) continue
      if (q === "" && !t.common) continue
      if (q !== "" && k.toLowerCase().indexOf(q) === -1 && t.description.toLowerCase().indexOf(q) === -1) continue
      out.push({ token: k, description: t.description })
    }
    out.sort(function (a, b) { return a.token < b.token ? -1 : (a.token > b.token ? 1 : 0) })
    return out
  }
  readonly property var categoryTokenList: categoryTokens(selectedCategoryId, categoryQuery)

  readonly property var layers: posData.layers
  readonly property var layerLabels: ({ base: "Base", keypad: "Keypad", function1: "Fn1", function2: "Fn2", function3: "Fn3" })

  property int profile: 1
  property string layerId: "base"
  property var layersData: ({})   // full {layer: {position: {kind, action, enabled}}} for the loaded profile
  property var pending: ({})      // local unsaved edits for the CURRENT layer: {position: action|null}
  property string status: ""
  property string selectedPosition: ""

  function keyList() {
    var out = []
    var hands = root.posData.hands
    for (var side in hands) {
      out = out.concat(hands[side].main, hands[side].thumb)
    }
    return out
  }
  readonly property var allKeys: keyList()

  function loadProfile(p) {
    if (!root.service) return
    root.profile = p
    root.pending = {}
    root.selectedPosition = ""
    root.status = "Loading profile " + p + "…"
    root.service.readProfile(p, function (message) {
      if (!message.ok) { root.status = message.error; return }
      root.layersData = message.layers
      root.status = ""
    })
  }

  function entryFor(position) {
    var layerData = root.layersData[root.layerId]
    return (layerData && layerData[position]) || null
  }

  function currentAction(position) {
    if (root.pending.hasOwnProperty(position)) return root.pending[position] || ""
    var entry = entryFor(position)
    return (entry && entry.kind === "remap" && entry.enabled) ? entry.action : ""
  }

  function isCustomized(position) {
    return currentAction(position) !== ""
  }

  function hasMacro(position) {
    if (root.pending.hasOwnProperty(position)) return false
    var entry = entryFor(position)
    return !!(entry && entry.kind === "macro")
  }

  function setPending(position, action) {
    var copy = Object.assign({}, root.pending)
    copy[position] = action || null
    root.pending = copy
  }

  function pendingCount() {
    return Object.keys(root.pending).length
  }

  function resetKey(position) {
    setPending(position, null)
  }

  function apply() {
    if (pendingCount() === 0) return
    var changes = {}
    changes[root.layerId] = root.pending
    root.status = "Saving…"
    root.service.writeProfile(root.profile, changes, function (message) {
      if (!message.ok) { root.status = message.error; return }
      root.status = "Saved to layout" + root.profile + ".txt."
      loadProfile(root.profile)
    })
  }

  function eject() {
    root.status = "Ejecting…"
    root.service.eject(function (message) {
      root.status = message.ok
        ? "v-Drive ejected. Safe to switch the keyboard back to normal mode."
        : message.error
    })
  }

  function mount() {
    root.status = "Mounting…"
    root.service.mount(function (message) {
      if (!message.ok) { root.status = message.error; return }
      root.status = ""
      loadProfile(root.profile)
    })
  }

  Component.onCompleted: loadProfile(1)
  onLayerIdChanged: selectedPosition = ""

  // Forwarded from the content layout so the popup that hosts this Editor
  // (Panel.qml's KeyboardPanel) can size itself to fit exactly — anchors
  // alone don't give a plain Item an implicit size, same issue the bar
  // button's implicitWidth/Height fix addressed.
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  ColumnLayout {
    id: content
    anchors.fill: parent
    spacing: Style.spacing.md

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.sm

      Text {
        text: "Profile"
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      Row {
        spacing: Style.spacing.xxs
        Repeater {
          model: 9
          delegate: Button {
            required property int index
            text: String(index + 1)
            selected: root.profile === index + 1
            onClicked: root.loadProfile(index + 1)
          }
        }
      }

      Item { Layout.fillWidth: true }

      Text {
        text: root.status
        color: Qt.darker(root.foreground, 1.3)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        Layout.preferredWidth: Style.space(260)
      }
    }

    Row {
      spacing: Style.spacing.xxs
      Repeater {
        model: root.layers
        delegate: Button {
          required property string modelData
          text: root.layerLabels[modelData] || modelData
          selected: root.layerId === modelData
          onClicked: root.layerId = modelData
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.spacing.lg

      RowLayout {
      Layout.fillHeight: true
      spacing: Style.spacing.lg

      Repeater {
        model: ["left", "right"]
        delegate: Item {
          required property string modelData
          readonly property var handData: root.posData.hands[modelData]
          // The thumb cluster's row/col in position_tokens.json are their own
          // small local grid (0,0-based), separate from the main well's —
          // offset them below and inset from the main well so the two blocks
          // don't render on top of each other.
          readonly property real mainRows: handData.main.reduce(function (m, k) { return Math.max(m, k.row + k.rowSpan) }, 0)
          readonly property var thumbKeys: handData.thumb.map(function (k) {
            var copy = Object.assign({}, k)
            copy.row = k.row + mainRows + 1
            copy.col = k.col + 2
            return copy
          })
          readonly property var keys: handData.main.concat(thumbKeys)
          readonly property real maxCol: keys.reduce(function (m, k) { return Math.max(m, k.col + k.colSpan) }, 0)
          readonly property real maxRow: keys.reduce(function (m, k) { return Math.max(m, k.row + k.rowSpan) }, 0)

          Layout.preferredWidth: maxCol * root.cell
          Layout.preferredHeight: maxRow * root.cell

          Repeater {
            model: parent.keys
            delegate: Rectangle {
              required property var modelData
              x: modelData.col * root.cell
              y: modelData.row * root.cell
              width: modelData.colSpan * root.cell - root.gap
              height: modelData.rowSpan * root.cell - root.gap
              radius: Style.cornerRadius
              color: root.selectedPosition === modelData.token
                ? Style.selectedFillFor(root.foreground, root.accent)
                : (root.isCustomized(modelData.token) ? Qt.alpha(root.accent, 0.18) : "transparent")
              border.width: 1
              border.color: root.hasMacro(modelData.token) ? root.accent : Qt.darker(root.foreground, 2.2)

              Column {
                anchors.centerIn: parent
                spacing: 0
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: modelData.label
                  color: root.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  visible: root.isCustomized(modelData.token)
                  text: root.currentAction(modelData.token)
                  color: root.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                  width: parent.width
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  visible: root.hasMacro(modelData.token)
                  text: "macro"
                  color: root.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function (mouse) {
                  if (mouse.button === Qt.RightButton) { root.resetKey(modelData.token); return }
                  root.selectedPosition = modelData.token
                }
              }
            }
          }
        }
      }
      } // end keyboard RowLayout

      // --- side panel: SmartSet-style category browser -------------------
      ColumnLayout {
        Layout.preferredWidth: Style.space(260)
        Layout.fillHeight: true
        spacing: Style.spacing.sm

        Text {
          Layout.fillWidth: true
          text: root.selectedPosition !== "" ? "Action for [" + root.selectedPosition + "]" : "Click a key to assign an action"
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        TextField {
          Layout.fillWidth: true
          visible: root.selectedPosition !== ""
          placeholderText: "Filter " + (root.selectedCategoryId) + "…"
          foreground: root.foreground
          accent: root.accent
          text: root.categoryQuery
          onTextChanged: root.categoryQuery = text
        }

        Flow {
          Layout.fillWidth: true
          visible: root.selectedPosition !== ""
          spacing: Style.spacing.xxs
          Repeater {
            model: root.categories
            delegate: Button {
              required property var modelData
              text: modelData.label
              selected: root.selectedCategoryId === modelData.id
              onClicked: root.selectedCategoryId = modelData.id
            }
          }
        }

        Button {
          text: "Clear (use default)"
          bordered: true
          visible: root.selectedPosition !== ""
          enabled: root.selectedPosition !== "" && (root.isCustomized(root.selectedPosition) || root.hasMacro(root.selectedPosition))
          opacity: enabled ? 1.0 : 0.5
          onClicked: root.resetKey(root.selectedPosition)
        }

        ListView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          visible: root.selectedPosition !== ""
          clip: true
          model: root.categoryTokenList
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: Style.space(30)
            radius: Style.cornerRadius
            color: root.currentAction(root.selectedPosition) === modelData.token
              ? Style.selectedFillFor(root.foreground, root.accent)
              : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.spacing.xs
              anchors.rightMargin: Style.spacing.xs
              spacing: Style.spacing.xs

              Text {
                text: modelData.token
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: root.currentAction(root.selectedPosition) === modelData.token
                Layout.preferredWidth: Style.space(70)
                elide: Text.ElideRight
              }
              Text {
                Layout.fillWidth: true
                text: modelData.description
                color: Qt.darker(root.foreground, 1.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setPending(root.selectedPosition, modelData.token)
            }
          }
        }

        Text {
          Layout.fillWidth: true
          visible: root.selectedPosition === ""
          text: "Pick a category, then click a token to assign it. Right-click a key on the board to clear it."
          color: Qt.darker(root.foreground, 1.4)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.sm

      Button {
        text: "Mount v-Drive"
        bordered: true
        visible: root.service && root.service.state !== "mounted"
        onClicked: root.mount()
      }
      Button {
        text: "Apply (" + root.pendingCount() + ")"
        bordered: true
        enabled: root.pendingCount() > 0
        opacity: enabled ? 1.0 : 0.5
        onClicked: root.apply()
      }
      Button {
        text: "Eject v-Drive"
        bordered: true
        visible: root.service && root.service.state === "mounted"
        onClicked: root.eject()
      }
      Item { Layout.fillWidth: true }
    }
  }
}
