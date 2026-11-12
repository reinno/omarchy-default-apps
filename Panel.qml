import QtQuick
import QtQuick.Controls as Controls
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
    property bool configuring: false
    readonly property var categoryOptions: [
        {key: "showBrowser", label: "Browser"},
        {key: "showEditor", label: "Editor"},
        {key: "showTerminal", label: "Terminal"},
        {key: "showAgent", label: "Coding agent"},
        {key: "showFileManager", label: "File manager"}
    ]

    function saveVisibility(key, value) {
        if (settingsWriter.running) return
        message = ""
        settingsWriter.command = ["omarchy", "bar", "set", root.moduleName,
                                  key, value ? "true" : "false", "--json"]
        settingsWriter.running = true
    }

    Process {
        id: settingsWriter
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.message = text.trim()
        }
        onExited: function(code) {
            if (code !== 0 && !root.message)
                root.message = "Could not save category settings. Please try again."
        }
    }
    readonly property var visibleCategories: {
        var keys = {"browser": "showBrowser", "editor": "showEditor",
                    "terminal": "showTerminal", "agent": "showAgent",
                    "file manager": "showFileManager"}
        return categories.filter(function(category) {
            return root.setting(keys[category.category], true) !== false
        })
    }
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("defaults.py").toString().replace(/^file:\/\//, ""))

    function refresh(args) {
        if (worker.running) return
        message = ""
        worker.command = ["python3", helper].concat(args || [])
        worker.running = true
    }
    onOpenedChanged: {
        if (opened) refresh([])
        else configuring = false
    }

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
        Controls.ScrollView {
            id: scroll
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth
            Column {
            id: content
            width: scroll.availableWidth
            spacing: Style.space(14)
            Keys.onEscapePressed: { if (root.configuring) root.configuring = false; else root.close() }
            PanelHero {
                title: root.configuring ? "Visible categories" : "Default apps"
                meta: root.configuring ? "Choose what appears" : "Preferred applications"
                iconComponent: Component {
                    Text {
                        text: "󰒓"
                        color: Commons.Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.display
                    }
                }
                trailingControl: Component {
                    Row {
                        spacing: Style.space(6)
                        PanelActionButton {
                            visible: !root.configuring
                            iconText: "󰑐"
                            tooltipText: "Refresh defaults"
                            focusable: true
                            enabled: !worker.running
                            onClicked: root.refresh([])
                        }
                        PanelActionButton {
                            iconText: root.configuring ? "󰁍" : "󰒓"
                            tooltipText: root.configuring ? "Back to defaults" : "Choose visible categories"
                            focusable: true
                            onClicked: root.configuring = !root.configuring
                        }
                    }
                }
            }
            PanelSeparator { width: parent.width }
            Text {
                width: parent.width
                visible: !root.configuring && root.visibleCategories.length === 0 && !worker.running && root.message === ""
                text: "No categories shown. Use the settings button above to enable categories."
                textFormat: Text.PlainText
                color: Commons.Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                wrapMode: Text.Wrap
            }
            Repeater {
                model: root.configuring ? root.categoryOptions : []
                Toggle {
                    required property var modelData
                    width: content.width
                    label: modelData.label
                    checked: root.setting(modelData.key, true) !== false
                    enabled: !settingsWriter.running
                    opacity: enabled ? 1 : 0.5
                    onClicked: root.saveVisibility(modelData.key, !checked)
                }
            }
            Repeater {
                model: root.configuring ? [] : root.visibleCategories
                Column {
                    id: categoryRow
                    required property var modelData
                    width: content.width
                    spacing: Style.space(6)
                    PanelSectionHeader {
                        text: categoryRow.modelData.category.toUpperCase()
                    }
                    Dropdown {
                        id: picker
                        width: parent.width
                        showLabel: false
                        options: categoryRow.modelData.apps
                        value: categoryRow.modelData.current || "Choose an app"
                        enabled: !worker.running && options.length > 0
                        opacity: enabled ? 1 : 0.5
                        onChanged: function(value) {
                            // The shared dropdown updates its value internally.
                            // Restore the binding so errors retain the actual default.
                            picker.value = Qt.binding(function() { return categoryRow.modelData.current || "Choose an app" })
                            if (value !== categoryRow.modelData.current)
                                root.refresh([categoryRow.modelData.category, value])
                        }
                    }
                }
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: settingsWriter.running ? "Saving…" : (worker.running ? "Loading…" : root.message)
                color: Commons.Color.foreground
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
            }

            }
        }
    }
}
