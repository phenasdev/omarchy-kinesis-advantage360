import QtQuick
import Quickshell
import Quickshell.Io

// Thin wrapper around bin/k360. Instantiated directly as a child of Panel.qml
// and Editor.qml (same pattern as the Logitech plugin's Service.qml) rather
// than registered as a manifest "service" — each owner gets its own cheap
// poller, and lsblk+udevadm are fast enough that sharing one isn't worth the
// extra plumbing.
Item {
  id: root

  property string pluginDir: ""
  readonly property string k360Path: pluginDir + "/bin/k360"

  // "no-drive" | "unmounted" | "mounted" | "busy"
  property string state: "no-drive"
  property string mountpoint: ""
  property string deviceName: ""
  property string lastError: ""

  function refresh() {
    if (mountProcess.running || ejectProcess.running) return
    detectProcess.running = true
  }

  function mount(callback) {
    root.state = "busy"
    mountProcess.callback = callback || null
    mountProcess.running = true
  }

  function eject(callback) {
    root.state = "busy"
    ejectProcess.callback = callback || null
    ejectProcess.running = true
  }

  // profile: int 1-9. callback(message) with message.layers on success.
  function readProfile(profile, callback) {
    readProcess.callback = callback || null
    readProcess.command = [root.k360Path, "read", String(profile)]
    readProcess.running = true
  }

  // changes: {layer: {position: action|null}}. callback(message).
  function writeProfile(profile, changes, callback) {
    writeProcess.callback = callback || null
    writeProcess.command = [root.k360Path, "write", String(profile), JSON.stringify(changes)]
    writeProcess.running = true
  }

  function _parse(text) {
    try {
      return JSON.parse(text)
    } catch (e) {
      return { ok: false, error: "bad response from k360" }
    }
  }

  function _applyState(message) {
    if (message.ok) {
      root.state = message.state
      root.mountpoint = message.mountpoint || ""
      root.deviceName = message.name || ""
      root.lastError = ""
    } else {
      root.state = "no-drive"
      root.mountpoint = ""
      root.lastError = message.error || ""
    }
  }

  Process {
    id: detectProcess
    command: [root.k360Path, "detect"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._applyState(root._parse(text))
    }
  }

  Process {
    id: mountProcess
    property var callback: null
    command: [root.k360Path, "mount"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = root._parse(text)
        root._applyState(message)
        if (mountProcess.callback) mountProcess.callback(message)
      }
    }
  }

  Process {
    id: ejectProcess
    property var callback: null
    command: [root.k360Path, "eject"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = root._parse(text)
        root.state = message.ok ? "no-drive" : root.state
        root.mountpoint = ""
        root.lastError = message.ok ? "" : (message.error || "")
        if (ejectProcess.callback) ejectProcess.callback(message)
      }
    }
  }

  Process {
    id: readProcess
    property var callback: null
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = root._parse(text)
        if (readProcess.callback) readProcess.callback(message)
      }
    }
  }

  Process {
    id: writeProcess
    property var callback: null
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = root._parse(text)
        if (writeProcess.callback) writeProcess.callback(message)
      }
    }
  }

  Timer {
    // v-Drive appearance/removal only happens on a deliberate onboard
    // shortcut, so a slow poll is plenty and keeps this idle-cheap.
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
