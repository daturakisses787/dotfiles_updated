import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: root

    width: config.ScreenWidth || Screen.width
    height: config.ScreenHeight || Screen.height
    color: "#1a1a2e"

    // Theme config
    readonly property color accentColor: config.AccentColor || "#c4b5fd"
    readonly property color textColor: config.TextColor || "#e2e8f0"
    readonly property color dimTextColor: config.DimTextColor || "#94a3b8"
    readonly property color errorColor: config.ErrorColor || "#f87171"
    readonly property color inputColor: config.InputColor || "#16213e"
    readonly property color inputTextColor: config.InputTextColor || "#e2e8f0"
    readonly property color panelColor: config.PanelColor || "#1a1a2e"
    readonly property real panelOpacity: parseFloat(config.PanelOpacity) || 0.85
    readonly property int fontSize: parseInt(config.FontSize) || 14
    readonly property int radius: parseInt(config.Radius) || 12

    TextConstants { id: textConstants }

    // Background
    Image {
        anchors.fill: parent
        source: config.Background
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    // Dark overlay
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.3
    }

    // Clock (top center)
    Column {
        anchors.top: parent.top
        anchors.topMargin: 60
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        Text {
            id: timeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 64
            font.weight: Font.Light
            color: root.textColor
            renderType: Text.NativeRendering

            function updateTime() {
                text = new Date().toLocaleString(Qt.locale(), config.ClockFormat || "HH:mm")
            }
        }

        Text {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 16
            color: root.dimTextColor
            renderType: Text.NativeRendering

            function updateDate() {
                text = new Date().toLocaleString(Qt.locale(), config.DateFormat || "dddd, d. MMMM")
            }
        }

        Timer {
            interval: 1000
            repeat: true
            running: true
            triggeredOnStart: true
            onTriggered: {
                timeLabel.updateTime()
                dateLabel.updateDate()
            }
        }
    }

    // Login fields (bottom center, no background panel)
    Column {
        id: loginColumn
        anchors.bottom: sessionSelect.top
        anchors.bottomMargin: 30
        anchors.horizontalCenter: parent.horizontalCenter
        width: 320
        spacing: 12

        // Username
        Rectangle {
            width: parent.width
            height: 44
            color: Qt.rgba(root.inputColor.r, root.inputColor.g, root.inputColor.b, 0.8)
            radius: root.radius / 2
            border.width: userField.activeFocus ? 2 : 0
            border.color: root.accentColor

            TextInput {
                id: userField
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: root.fontSize
                color: root.inputTextColor
                clip: true
                text: userModel.lastUser

                KeyNavigation.tab: passwordField

                Keys.onReturnPressed: passwordField.forceActiveFocus()
                Keys.onEnterPressed: passwordField.forceActiveFocus()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: root.fontSize
                    color: root.dimTextColor
                    text: "Username"
                    visible: !userField.text && !userField.activeFocus
                    renderType: Text.NativeRendering
                }
            }
        }

        // Password
        Rectangle {
            width: parent.width
            height: 44
            color: Qt.rgba(root.inputColor.r, root.inputColor.g, root.inputColor.b, 0.8)
            radius: root.radius / 2
            border.width: passwordField.activeFocus ? 2 : 0
            border.color: root.accentColor

            TextInput {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: root.fontSize
                color: root.inputTextColor
                echoMode: TextInput.Password
                clip: true

                KeyNavigation.tab: loginArea

                Keys.onReturnPressed: doLogin()
                Keys.onEnterPressed: doLogin()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: root.fontSize
                    color: root.dimTextColor
                    text: "Password"
                    visible: !passwordField.text && !passwordField.activeFocus
                    renderType: Text.NativeRendering
                }
            }
        }

        // Error message
        Text {
            id: errorMessage
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: root.fontSize - 2
            color: root.errorColor
            visible: text !== ""
            renderType: Text.NativeRendering
        }

        // Login button
        Rectangle {
            id: loginButton
            width: parent.width
            height: 44
            radius: root.radius / 2
            color: loginArea.containsMouse
                ? Qt.lighter(root.accentColor, 1.1)
                : root.accentColor

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "Login"
                font.pixelSize: root.fontSize
                font.weight: Font.DemiBold
                color: "#1a1a2e"
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: loginArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: doLogin()
            }
        }
    }

    // Session selector (bottom center)
    ComboBox {
        id: sessionSelect
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        anchors.horizontalCenter: parent.horizontalCenter
        width: 200
        height: 36
        model: sessionModel
        index: sessionModel.lastIndex
        color: Qt.rgba(root.panelColor.r, root.panelColor.g, root.panelColor.b, 0.6)
        textColor: root.dimTextColor
        borderColor: "transparent"
        focusColor: root.accentColor
        hoverColor: root.inputColor
        font.pixelSize: root.fontSize - 2
    }

    // Power buttons (bottom right)
    Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 30
        spacing: 12

        ImageButton {
            id: rebootButton
            width: 32
            height: 32
            source: "reboot.svg"
            visible: sddm.canReboot
            onClicked: sddm.reboot()
        }

        ImageButton {
            id: shutdownButton
            width: 32
            height: 32
            source: "shutdown.svg"
            visible: sddm.canPowerOff
            onClicked: sddm.powerOff()
        }
    }

    // Login logic
    function doLogin() {
        errorMessage.text = ""
        sddm.login(userField.text, passwordField.text, sessionSelect.index)
    }

    // Handle login failure
    Connections {
        target: sddm
        function onLoginFailed() {
            errorMessage.text = "Login failed. Please try again."
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
    }

    // Initial focus
    Component.onCompleted: {
        if (userField.text !== "") {
            passwordField.forceActiveFocus()
        } else {
            userField.forceActiveFocus()
        }
    }
}
