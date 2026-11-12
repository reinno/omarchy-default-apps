import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Panel {
    id: root
    moduleName: "reinno.default-apps"
    ipcTarget: "reinno.default-apps"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    property var categories: []
    property string message: ""
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("defaults.py").toString().replace(/^file:\/\//, ""))

    function refresh(args) {
        if (worker.running) return
        message = ""
        worker.command = ["python3", helper].concat(args || [])
        worker.running = true
    }
    onOpenedChanged: if (opened) refresh([])

    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return
                try { root.categories = JSON.parse(text) }
                catch (e) { root.message = "Could not read default apps." }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.message = text.trim() }
        onExited: function(code) {
            if (code !== 0 && !root.message) root.message = "Could not update defaults. Try refreshing."
        }
    }
    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰒓"
        tooltipText: "Default apps"
        onPressed: root.toggle()
    }
    KeyboardPanel {
        id: popup
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        contentWidth: popup.fittedContentWidth(Style.space(360))
        contentHeight: popup.fittedContentHeight(content.implicitHeight, Style.space(520))
        focusTarget: content
        Column {
            id: content
            width: parent.width
            spacing: 12
            Keys.onEscapePressed: root.close()
            Text { text: "Default apps"; color: Commons.Color.foreground; font.pixelSize: 20 }
            Repeater {
                model: root.categories
                Column {
                    required property var modelData
                    width: content.width
                    spacing: 4
                    Text {
                        width: parent.width
                        text: modelData.category.charAt(0).toUpperCase() + modelData.category.slice(1) + " · " + modelData.current
                        color: Commons.Color.foreground
                        elide: Text.ElideRight
                    }
                    ComboBox {
                        width: parent.width
                        model: modelData.apps
                        textRole: "label"
                        enabled: !worker.running && modelData.apps.length > 0
                        currentIndex: {
                            for (var i = 0; i < modelData.apps.length; i++)
                                if (modelData.apps[i].value === modelData.current) return i
                            return -1
                        }
                        displayText: currentIndex < 0 ? "Choose an installed app…" : currentText
                        onActivated: function(index) { root.refresh([modelData.category, modelData.apps[index].value]) }
                    }
                }
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: worker.running ? "Loading…" : root.message
                color: Commons.Color.foreground
                wrapMode: Text.Wrap
            }
            Button { text: "Refresh"; enabled: !worker.running; onClicked: root.refresh([]) }
        }
    }
}
