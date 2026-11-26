import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import "../services"
import "CombinationActions.js" as Actions

Pane {
    id: root
    visible: false
    padding: 0
    property var allEntities: []
    property string shortcutId: ""
    property var draft: []
    property int editingIndex: -1
    property string selectedEntityId: ""
    property string entitySearchText: ""
    property bool choosingEntity: false
    readonly property var selectedEntity: allEntities.find(e => e.entityId === selectedEntityId) || null
    property var availableFields: []
    readonly property var field: availableFields[fieldPicker.currentIndex] || null
    readonly property var choices: field && field.options ? field.options : []
    readonly property var value: field && field.options ? choices[valuePicker.currentIndex] : (numberInput.text.trim() ? Number(numberInput.text) : NaN)
    readonly property var selectableEntities: allEntities.filter(e => {
        const query = entitySearchText.toLowerCase();
        return ["fan", "climate", "light", "switch", "input_boolean", "select", "input_select", "number", "input_number"].includes(e.domain)
            && (e.friendlyName + " " + e.entityId).toLowerCase().includes(query);
    })

    function tr(text) { return I18n.trFor("homeAssistantMonitor", text); }
    function fieldsFor(entity) {
        if (!entity) return [];
        let sections = [];
        if (entity.domain === "fan") sections = EntityControlResolver.getFanSections(entity);
        if (entity.domain === "climate") sections = EntityControlResolver.getClimateSections(entity);
        if (entity.domain === "light") sections = EntityControlResolver.getLightSections(entity);
        return Actions.fields(entity, sections);
    }
    function valueLabel(f, v, index) {
        if (f.gears) return tr("Level") + " " + (index + 1);
        if (typeof v === "boolean" || f.key === "power") return v === true || v === "on" ? tr("On") : tr("Off");
        return String(v);
    }
    function resetValue() {
        valuePicker.currentIndex = 0;
        numberInput.text = field && field.min !== undefined ? String(field.min) : "";
    }
    function open(id) {
        const shortcut = HomeAssistantService.shortcuts.find(s => s.id === id);
        shortcutId = id;
        nameInput.text = shortcut ? shortcut.name : "";
        draft = shortcut ? JSON.parse(JSON.stringify(shortcut.actions)) : [];
        editingIndex = -1;
        search.text = "";
        selectedEntityId = "";
        entitySearchText = "";
        choosingEntity = false;
        visible = true;
        nameInput.forceActiveFocus();
    }
    function close() { visible = false; }
    function selectEntity(entityId) {
        const entity = allEntities.find(e => e.entityId === entityId);
        // DTextField emits textEdited for programmatic text changes as well.
        search.text = entity ? entity.friendlyName : entityId;
        selectedEntityId = entityId;
        entitySearchText = "";
        choosingEntity = false;
    }
    function editAction(index) {
        const a = draft[index];
        editingIndex = index;
        selectEntity(a.entityId);
        fieldPicker.currentIndex = availableFields.findIndex(f => f.key === a.key);
        valuePicker.currentIndex = choices.indexOf(a.value);
        numberInput.text = String(a.value);
    }
    function storeAction() {
        const label = selectedEntity.friendlyName + " · " + tr(field.label) + ": " + valueLabel(field, value, valuePicker.currentIndex);
        const a = Actions.action(selectedEntity, field, value, label);
        const list = draft.slice();
        const duplicate = list.findIndex((item, i) => i !== editingIndex && item.entityId === a.entityId && item.key === a.key);
        if (editingIndex >= 0) list[editingIndex] = a;
        else if (duplicate >= 0) list[duplicate] = a;
        else list.push(a);
        if (editingIndex >= 0 && duplicate >= 0) list.splice(duplicate, 1);
        draft = list;
        editingIndex = -1;
    }
    onSelectedEntityIdChanged: { availableFields = fieldsFor(allEntities.find(e => e.entityId === selectedEntityId)); fieldPicker.currentIndex = 0; resetValue(); }
    Keys.onEscapePressed: close()

    component FormComboBox: DDropdown {
        id: control
        property var model: []
        property int currentIndex: -1
        property string displayText: currentIndex >= 0 && currentIndex < model.length ? String(model[currentIndex]) : ""
        signal activated(int index)
        options: model
        currentValue: displayText
        showLabel: true
        dropdownWidth: width
        clampMenuWidth: true
        triggerHeight: 40
        focusPolicy: Qt.StrongFocus
        onDisplayTextChanged: currentValue = displayText
        onValueChanged: value => {
            currentIndex = model.indexOf(value);
            activated(currentIndex);
            currentValue = displayText;
        }
    }

    background: Rectangle {
        color: Theme.foregroundColor(Theme.hostSurface)
        radius: Theme.cornerRadiusXL
        border.width: Theme.layerOutlineWidth
        border.color: Theme.outlineMedium
    }
    MouseArea { anchors.fill: parent; onClicked: root.forceActiveFocus() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: root.tr("Edit scene button")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }
            PanelActionButton {
                iconName: "close"
                Accessible.name: root.tr("Close")
                onClicked: root.close()
            }
        }
        DTextField {
            id: nameInput
            objectName: "combinationName"
            Layout.fillWidth: true
            controlHeight: 40
            placeholderText: root.tr("Button name")
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacingM

            ScrollView {
                id: addedActionsScroll
                objectName: "addedActionsPane"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: addedActionsScroll.availableWidth
                    spacing: Theme.spacingS
                    StyledText {
                        text: root.tr("Added actions") + " · " + root.draft.length
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }
                    Repeater {
                        model: root.draft
                        delegate: RowLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: Theme.spacingXS
                            StyledButton {
                                id: actionButton
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                readonly property bool selected: root.editingIndex === index
                                leftPadding: Theme.spacingM
                                rightPadding: Theme.spacingM
                                topPadding: Theme.spacingS
                                bottomPadding: Theme.spacingS
                                implicitHeight: Math.max(48, actionLabel.implicitHeight + topPadding + bottomPadding)
                                text: modelData.label
                                contentItem: StyledText {
                                    id: actionLabel
                                    text: actionButton.text
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    radius: Theme.cornerRadius
                                    color: actionButton.selected ? Theme.primaryContainer
                                        : (actionButton.hovered ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow)
                                    border.width: 1
                                    border.color: actionButton.selected || actionButton.visualFocus ? Theme.primary
                                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                                }
                                onClicked: root.editAction(index)
                            }
                            PanelActionButton {
                                id: removeActionButton
                                iconName: "close"
                                inactiveBackgroundColor: "transparent"
                                Accessible.name: root.tr("Remove action")
                                onClicked: {
                                    const list = root.draft.slice();
                                    list.splice(index, 1);
                                    root.draft = list;
                                    root.editingIndex = -1;
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
            }

            ScrollView {
                id: actionScroll
                objectName: "entityEditorPane"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: actionScroll.availableWidth
                    spacing: Theme.spacingS
                    StyledText {
                        text: root.tr(root.editingIndex >= 0 ? "Edit action" : "Add action")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }
                    DTextField {
                        id: search
                        objectName: "entitySearch"
                        controlHeight: 40
                        Layout.fillWidth: true
                        placeholderText: root.tr("Search and select entity")
                        onTextEdited: {
                            root.entitySearchText = text;
                            root.selectedEntityId = "";
                            root.choosingEntity = true;
                        }
                        onFocusStateChanged: hasFocus => {
                            if (hasFocus) root.choosingEntity = true;
                        }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(contentHeight, 180)
                        visible: root.choosingEntity && count > 0
                        clip: true
                        model: root.selectableEntities
                        spacing: Theme.spacingXS
                        delegate: DButton {
                            required property var modelData
                            width: ListView.view.width
                            maximumWidth: width
                            variant: "text"
                            radius: Theme.cornerRadius
                            textColor: Theme.surfaceText
                            text: modelData.friendlyName + " · " + modelData.entityId
                            onClicked: {
                                root.selectEntity(modelData.entityId);
                            }
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.choosingEntity && root.selectableEntities.length === 0
                        text: root.tr("No matching entities")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                    FormComboBox {
                        id: fieldPicker
                        onCurrentIndexChanged: root.resetValue()
                        Layout.fillWidth: true
                        model: root.availableFields.map(f => root.tr(f.label))
                    }
                    FormComboBox {
                        id: valuePicker
                        Layout.fillWidth: true
                        visible: root.field !== null && !!root.field.options
                        model: root.choices.map((v, i) => root.valueLabel(root.field, v, i))
                    }
                    DTextField {
                        controlHeight: 40
                        id: numberInput
                        Layout.fillWidth: true
                        visible: root.field !== null && !root.field.options
                    }
                    StyledText {
                        visible: numberInput.visible
                        text: root.field ? root.field.min + " – " + root.field.max + " · " + root.tr("Step") + " " + root.field.step : ""
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    DButton {
                        variant: "tonal"
                        iconName: root.editingIndex >= 0 ? "check" : "add"
                        Layout.fillWidth: true
                        text: root.tr(root.editingIndex >= 0 ? "Update action" : "Add action")
                        enabled: !!root.selectedEntity && Actions.validValue(root.field, root.value)
                        onClicked: root.storeAction()
                    }
                    StyledText { text: root.tr("Unspecified properties stay unchanged"); Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            Item { Layout.fillWidth: true }
            DButton { variant: "text"; text: root.tr("Cancel"); onClicked: root.close() }
            DButton {
                objectName: "saveCombination"
                text: root.tr("Save")
                iconName: "check"
                enabled: nameInput.text.trim().length > 0 && root.draft.length > 0 && root.editingIndex < 0
                onClicked: {
                    HomeAssistantService.saveCombination(root.shortcutId, nameInput.text, Actions.ordered(root.draft));
                    root.close();
                }
            }
        }
    }
}
