/*
 * Copyright 2014 Canonical Ltd.
 *
 * This file is part of webbrowser-app.
 *
 * webbrowser-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * webbrowser-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import QtQuick.Window 2.0
import com.canonical.Oxide 1.4 as Oxide
import Ubuntu.Components 1.1
import ".."

Item {
    id: popup

    property var popupWindowController
    property var webContext
    property alias request: popupWebview.request
    property alias url: popupWebview.url

    Rectangle {
        color: "#F2F1F0"
        anchors.fill: parent
    }

    Item {
        anchors {
            fill: parent
            margins: units.gu(1)
        }


        MouseArea {
            id: controls

            property int initMouseY: 0
            property int prevMouseY: 0
            onPressed: {
                initMouseY = mouse.y
                prevMouseY = initMouseY
            }
            onReleased: {
                if ((prevMouseY - initMouseY) > (popup.height / 3)) {
                    if (popupWindowController) {
                        popupWindowController.handleViewRemoved(popup)
                        return
                    }
                }
                popup.y = 0
            }
            onMouseYChanged: {
                if (popupWindowController) {
                    var diff = mouseY - initMouseY
                    prevMouseY = mouseY
                    popupWindowController.onOverlayMoved(popup, diff)
                }
            }

            height: units.gu(6)
            width: parent.width - units.gu(6)

            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }

            ChromeButton {
                id: closeButton
                objectName: "overlayCloseButton"
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                height: parent.height
                width: height

                iconName: "dropdown-menu"
                iconSize: 0.6 * height

                enabled: true
                visible: true

                onTriggered: {
                    if (popupWindowController) {
                        popupWindowController.handleViewRemoved(popup)
                    }
                }
            }

            Label {
                anchors {
                    left: closeButton.right
                    right: buttonOpenInBrowser.left
                    rightMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }

                text: popupWebview.title ? popupWebview.title : popupWebview.url
                elide: Text.ElideRight
            }

            ChromeButton {
                id: buttonOpenInBrowser
                objectName: "overlayButtonOpenInBrowser"
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: units.gu(1)
                }

                height: parent.height
                width: height

                iconName: "external-link"
                iconSize: 0.6 * height

                enabled: true
                visible: true

                onTriggered: {
                    if (popupWindowController) {
                        popupWindowController.handleOpenInUrlBrowserForView(
                                 popupWebview.url, popup)
                    }
                }
            }
        }

        /**
         * Use a plain oxide webview
         *
         */
        WebViewImpl {
            id: popupWebview

            objectName: "overlayWebview"

            context: webContext

            onUrlChanged: console.log('url changed: ' + url)

            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                top: controls.bottom
            }

            onNewViewRequested: {
                console.log('--- new view requested')
                if (popupWindowController) {
                    popupWindowController.createPopupView(
                        popup.parent, request, false, context)
                }
            }

            function isNewForegroundWebViewDisposition(disposition) {
                return disposition === Oxide.NavigationRequest.DispositionNewPopup ||
                       disposition === Oxide.NavigationRequest.DispositionNewForegroundTab;
            }

            onNavigationRequested: {
                console.log('--- onNavigationRequested requested ')
                var url = request.url.toString()
                if (isNewForegroundWebViewDisposition(request.disposition)) {
                    popupWindowController.handleNewForegroundNavigationRequest(
                                url, request, false)
                    return
                }
                request.action = Oxide.NavigationRequest.ActionAccept
            }

            onCloseRequested: {
                if (popupWindowController) {
                    popupWindowController.handleViewRemoved(popup)
                }
            }
        }
    }
}
