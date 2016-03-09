/*
 * Copyright 2014-2016 Canonical Ltd.
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

import QtQuick 2.4
import QtQuick.Window 2.2
import com.canonical.Oxide 1.8 as Oxide
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import Ubuntu.UnityWebApps 0.1 as UnityWebApps
import Ubuntu.Web 0.2
import "../actions" as Actions
import ".."

WebViewImpl {
    id: webview

    property bool developerExtrasEnabled: false
    property string webappName: ""
    property string localUserAgentOverride: ""
    property var webappUrlPatterns: null
    property string popupRedirectionUrlPrefixPattern: ""
    property url dataPath
    property var popupController
    property var overlayViewsParent: webview.parent
    property bool wide: false
    property var mediaAccessDialogComponent

    // Mostly used for testing & avoid external urls to
    //  "leak" in the default browser. External URLs corresponds
    //  to URLs that are not included in the set defined by the url patterns
    //  (if any) or navigations resulting in new windows being created.
    property bool blockOpenExternalUrls: false

    signal samlRequestUrlPatternReceived(string urlPattern)
    signal themeColorMetaInformationDetected(string theme_color)

    // Those signals are used for testing purposes to externally
    //  track down the various internal logic & steps of a popup lifecycle.
    signal openExternalUrlTriggered(string url)
    signal gotRedirectionUrl(string url)
    property bool runningLocalApplication: false

    function openOverlayForUrl(overlayUrl) {
        if (popupController) {
            popupController.createPopupViewForUrl(
                        overlayViewsParent,
                        overlayUrl,
                        true,
                        context)
        }
    }

    currentWebview: webview
    filePicker: filePickerLoader.item

    context: WebContext {
        dataPath: webview.dataPath
        userAgent: localUserAgentOverride ? localUserAgentOverride : defaultUserAgent

        userScripts: [
            Oxide.UserScript {
                context: "oxide://webapp-specific-page-metadata-collector/"
                url: Qt.resolvedUrl("webapp-specific-page-metadata-collector.js")
                incognitoEnabled: false
                matchAllFrames: false
            }
        ]
    }
    messageHandlers: [
        Oxide.ScriptMessageHandler {
            msgId: "webapp-specific-page-metadata-detected"
            contexts: ["oxide://webapp-specific-page-metadata-collector/"]
            callback: function(msg, frame) {
                handlePageMetadata(msg.args)
            }
        }
    ]

    preferences.allowFileAccessFromFileUrls: runningLocalApplication
    preferences.allowUniversalAccessFromFileUrls: runningLocalApplication
    preferences.localStorageEnabled: true
    preferences.appCacheEnabled: true

    onNewViewRequested: popupController.createPopupViewForRequest(overlayViewsParent, request, true, context)

    property QtObject contextModel: null
    contextualActions: ActionList {
        Actions.OpenLinkInWebBrowser {
            objectName: "OpenLinkInWebBrowser"
            enabled: contextModel && contextModel.linkUrl.toString()
            onTriggered: openUrlExternally(contextModel.linkUrl)
        }
        Actions.CopyLink {
            enabled: webview.contextModel && webview.contextModel.linkUrl.toString()
            onTriggered: Clipboard.push(["text/plain", contextModel.linkUrl.toString()])
            objectName: "CopyLinkContextualAction"
        }
        Actions.CopyImage {
            enabled: webview.contextModel &&
                     (webview.contextModel.mediaType === Oxide.WebView.MediaTypeImage) &&
                     webview.contextModel.srcUrl.toString()
            onTriggered: Clipboard.push(["text/plain", contextModel.srcUrl.toString()])
            objectName: "CopyImageContextualAction"
        }
        Actions.Undo {
            enabled: webview.contextModel && webview.contextModel.isEditable &&
                     (webview.contextModel.editFlags & Oxide.WebView.UndoCapability)
            onTriggered: webview.executeEditingCommand(Oxide.WebView.EditingCommandUndo)
            objectName: "UndoContextualAction"
        }
        Actions.Redo {
            enabled: webview.contextModel && webview.contextModel.isEditable &&
                     (webview.contextModel.editFlags & Oxide.WebView.RedoCapability)
            onTriggered: webview.executeEditingCommand(Oxide.WebView.EditingCommandRedo)
            objectName: "RedoContextualAction"
        }
        Actions.Cut {
            enabled: webview.contextModel && webview.contextModel.isEditable &&
                     (webview.contextModel.editFlags & Oxide.WebView.CutCapability)
            onTriggered: webview.executeEditingCommand(Oxide.WebView.EditingCommandCut)
            objectName: "CutContextualAction"
        }
        Actions.Copy {
            enabled: webview.contextModel && webview.contextModel.isEditable &&
                     (webview.contextModel.editFlags & Oxide.WebView.CopyCapability)
            onTriggered: webview.executeEditingCommand(Oxide.WebView.EditingCommandCopy)
            objectName: "CopyContextualAction"
        }
        Actions.Paste {
            enabled: webview.contextModel && webview.contextModel.isEditable &&
                     (webview.contextModel.editFlags & Oxide.WebView.PasteCapability)
            onTriggered: webview.executeEditingCommand(Oxide.WebView.EditingCommandPaste)
            objectName: "PasteContextualAction"
        }
        Actions.Erase {
            enabled: webview.contextModel && webview.contextModel.isEditable &&
                     (webview.contextModel.editFlags & Oxide.WebView.EraseCapability)
            onTriggered: webview.executeEditingCommand(Oxide.WebView.EditingCommandErase)
            objectName: "EraseContextualAction"
        }
        Actions.SelectAll {
            enabled: webview.contextModel && webview.contextModel.isEditable &&
                     (webview.contextModel.editFlags & Oxide.WebView.SelectAllCapability)
            onTriggered: webview.executeEditingCommand(Oxide.WebView.EditingCommandSelectAll)
            objectName: "SelectAllContextualAction"
        }
    }
    function contextMenuOnCompleted(menu) {
        if (!menu || !menu.contextModel) {
            return
        }
        contextModel = menu.contextModel

        var isImageMediaType =
                ((contextModel.mediaType === Oxide.WebView.MediaTypeImage) ||
                 (contextModel.mediaType === Oxide.WebView.MediaTypeCanvas))
             && contextModel.hasImageContents;

        if (contextModel.linkUrl.toString() ||
            contextModel.srcUrl.toString() ||
            contextModel.selectionText ||
            (contextModel.isEditable && contextModel.editFlags) ||
            isImageMediaType) {
            menu.show()
        } else {
            contextModel.close()
        }
    }
    Component {
        id: contextMenuNarrowComponent
        ContextMenuMobile {
            actions: contextualActions
            Component.onCompleted: webview.contextMenuOnCompleted(this)
        }
    }
    Component {
        id: contextMenuWideComponent
        ContextMenuWide {
            associatedWebview: webview
            parent: browser
            actions: contextualActions
            Component.onCompleted: webview.contextMenuOnCompleted(this)
        }
    }
    contextMenu: webview.wide ? contextMenuWideComponent : contextMenuNarrowComponent

    Connections {
        target: webview.visible ? webview : null

        /**
         * We are only connecting to the mediaAccessPermission signal is we are current
         * the only view visible (no overlay present). In the case of an overlay,
         * the absence of a signal handler in the main view, oxide's default behavior
         * is triggered and the request is denied.
         *
         * See the browser's webbrowser/Browser.qml source for additional comments.
         */
        onMediaAccessPermissionRequested:PopupUtils.open(mediaAccessDialogComponent, null, { request: request })
    }

    StateSaver.properties: "url"
    StateSaver.enabled: !runningLocalApplication

    function handleSAMLRequestPattern(urlPattern) {
        webappUrlPatterns.push(urlPattern)

        samlRequestUrlPatternReceived(urlPattern)
    }

    function isRunningAsANamedWebapp() {
        return webview.webappName && typeof(webview.webappName) === 'string' && webview.webappName.length != 0
    }

    function haveValidUrlPatterns() {
        return webappUrlPatterns && webappUrlPatterns.length !== 0
    }

    function isNewForegroundWebViewDisposition(disposition) {
        return disposition === Oxide.NavigationRequest.DispositionNewPopup ||
               disposition === Oxide.NavigationRequest.DispositionNewForegroundTab;
    }

    function openUrlExternally(url) {
        webview.openExternalUrlTriggered(url)
        if (! webview.blockOpenExternalUrls) {
            Qt.openUrlExternally(url)
        }
    }

    function shouldAllowNavigationTo(url) {
        // The list of url patterns defined by the webapp takes precedence over command line
        if (isRunningAsANamedWebapp()) {
            if (unityWebapps.model.exists(unityWebapps.name) &&
                unityWebapps.model.doesUrlMatchesWebapp(unityWebapps.name, url)) {
                return true;
            }
        }

        // We still take the possible additional patterns specified in the command line
        // (the in the case of finer grained ones specifically for the container and not
        // as an 'install source' for the webapp).
        if (haveValidUrlPatterns()) {
            for (var i = 0; i < webappUrlPatterns.length; ++i) {
                var pattern = webappUrlPatterns[i]
                if (url.match(pattern)) {
                    return true;
                }
            }
        }

        return false;
    }

    function navigationRequestedDelegate(request) {
        var url = request.url.toString()
        if (runningLocalApplication && url.indexOf("file://") !== 0) {
            request.action = Oxide.NavigationRequest.ActionReject
            openUrlExternally(url)
            return
        }

        request.action = Oxide.NavigationRequest.ActionReject
        if (isNewForegroundWebViewDisposition(request.disposition)) {
            request.action = Oxide.NavigationRequest.ActionAccept
            popupController.handleNewForegroundNavigationRequest(url, request, true)
            return
        }

        // Pass-through if we are not running as a named webapp (--webapp='Gmail')
        // or if we dont have a list of url patterns specified to filter the
        // browsing actions
        if ( ! webview.haveValidUrlPatterns() && ! webview.isRunningAsANamedWebapp()) {
            request.action = Oxide.NavigationRequest.ActionAccept
            return
        }

        if (webview.shouldAllowNavigationTo(url))
            request.action = Oxide.NavigationRequest.ActionAccept

        // SAML requests are used for instance by Google Apps for your domain;
        // they are implemented as a HTTP redirect to a URL containing the
        // query parameter called "SAMLRequest".
        // Besides letting the request through, we must also add the SAML
        // domain to the list of the allowed hosts.
        if (request.disposition === Oxide.NavigationRequest.DispositionCurrentTab &&
            url.indexOf("SAMLRequest") > 0) {
            var urlRegExp = new RegExp("https?://([^?/]+)")
            var match = urlRegExp.exec(url)
            var host = match[1]
            var escapeDotsRegExp = new RegExp("\\.", "g")
            var hostPattern = "https?://" + host.replace(escapeDotsRegExp, "\\.") + "/*"

            console.log("SAML request detected. Adding host pattern: " + hostPattern)

            handleSAMLRequestPattern(hostPattern)

            request.action = Oxide.NavigationRequest.ActionAccept
        }

        if (request.action === Oxide.NavigationRequest.ActionReject) {
            console.debug('Opening: ' + url + ' in the browser window.')
            openUrlExternally(url)
        }
    }

    // Small shim needed when running as a webapp to wire-up connections
    // with the webview (message received, etc…).
    // This is being called (and expected) internally by the webapps
    // component as a way to bind to a webview lookalike without
    // reaching out directly to its internals (see it as an interface).
    function getUnityWebappsProxies() {
        var eventHandlers = {
            onAppRaised: function () {
                if (webbrowserWindow) {
                    try {
                        webbrowserWindow.raise();
                    } catch (e) {
                        console.debug('Error while raising: ' + e);
                    }
                }
            }
        };
        return UnityWebAppsUtils.makeProxiesForWebViewBindee(webview, eventHandlers)
    }

    onGeolocationPermissionRequested: {
        if (__runningConfined && (request.origin == request.embedder)) {
            // When running confined, querying the location service will trigger
            // a system prompt (trust store), so no need for a custom one.
            request.accept()
        } else {
            requestGeolocationPermission(request)
        }
    }

    function handlePageMetadata(metadata) {
        if (metadata.type === 'manifest') {
            var request = new XMLHttpRequest();
            request.onreadystatechange = function() {
                if (request.readyState === XMLHttpRequest.DONE) {
                    try {
                        var manifest = JSON.parse(request.responseText);
                        if (manifest['theme_color']
                                && manifest['theme_color'].length !== 0) {
                            themeColorMetaInformationDetected(manifest['theme_color'])
                        }
                    } catch(e) {}
                }
            }
            request.open("GET", metadata.manifest);
            request.send();
        } else if (metadata.type === 'theme-color') {
            if (metadata['theme_color']
                    && metadata['theme_color'].length !== 0) {
                themeColorMetaInformationDetected(metadata['theme_color'])
            }
        }
    }

    onShowDownloadDialog: {
       if (downloadDialogLoader.status === Loader.Ready) {
           var downloadDialog = PopupUtils.open(downloadDialogLoader.item, webview, {"contentType" : contentType,
                                                                                     "downloadId" : downloadId,
                                                                                     "singleDownload" : downloader,
                                                                                     "filename" : filename,
                                                                                     "mimeType" : mimeType})
           downloadDialog.startDownload.connect(startDownload)
        }
    }

    Loader {
        id: downloadDialogLoader
        source: "ContentDownloadDialog.qml"
        asynchronous: true
    }

    Loader {
        id: filePickerLoader
        source: "ContentPickerDialog.qml"
        asynchronous: true
    }
}
