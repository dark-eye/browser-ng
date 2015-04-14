/*
 * Copyright 2013-2014 Canonical Ltd.
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
import Ubuntu.Components 1.1

Rectangle {
    id: suggestions

    property alias model: historySuggestionsSource.model
    property alias count: historySuggestionsSource.count
    property alias contentHeight: suggestionsContainer.contentHeight

    signal selected(url url)

    radius: units.gu(0.5)
    border {
        color: "#dedede"
        width: 1
    }

    clip: true

    Flickable {
        id: suggestionsContainer
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: parent.height
        contentHeight: suggestionsList.height

        Column {
            id: suggestionsList

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: childrenRect.height

            Repeater {
                id: historySuggestionsSource
                delegate: Suggestion {
                    title: historySuggestionsSource.highlightTerms(model.title)
                    subtitle: historySuggestionsSource.highlightTerms(model.url)
                    url: model.url

                    // -2 since the repeater is an extra child
                    showDivider: index < (suggestionsList.children.length - 2)

                    onSelected: suggestions.selected(url)
                }

                function escapeTerm(term) {
                    // Build a regular expression suitable for highlighting a term
                    // in a case-insensitive manner and globally, by escaping
                    // special characters (a simpler version of preg_quote).
                    var escaped = term.replace(/[().?]/g, '\\$&')
                    return new RegExp(escaped, 'ig')
                }

                function highlightTerms(text) {
                    // Highlight the matching terms (bold and Ubuntu orange)
                    if (text === undefined) {
                        return ''
                    }
                    var highlighted = text.toString()
                    var count = model.terms.length
                    var highlight = '<b><font color="%1">$&</font></b>'.arg(UbuntuColors.orange)
                    for (var i = 0; i < count; ++i) {
                        var term = model.terms[i]
                        highlighted = highlighted.replace(escapeTerm(term), highlight)
                    }
                    highlighted = highlighted.replace(new RegExp('&', 'g'), '&amp;')
                    highlighted = '<html>' + highlighted + '</html>'
                    return highlighted
                }
            }
        }
    }

    Scrollbar {
        flickableItem: suggestionsContainer
        align: Qt.AlignTrailing
    }
}
