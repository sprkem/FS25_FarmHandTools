---
-- CameraSettings
-- In-game settings menu for Free Camera mod
---

CameraSettings = {}
CameraSettings.CONTROLS = {}

CameraSettings.menuItems = {
    'cameraMoveSpeed',
    'cameraSprintMultiplier',
    'cameraZoomMultiplier',
    'cameraZoomSpeed',
    'cameraLeanAngle',
    'cameraSpeedPreset1',
    'cameraSpeedPreset2',
    'cameraSpeedPreset3',
    'cameraSpeedPreset4'
}

-- SHARED CONSTANTS
local SPEED_VALUES = { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20 }
local SPEED_STRINGS = { "0.1", "0.2", "0.3", "0.4", "0.5", "0.6", "0.7", "0.8", "0.9", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "12", "14", "16", "18", "20" }

local SPRINT_VALUES = { 2, 3, 4, 5, 6, 7, 8, 9, 10 }
local SPRINT_STRINGS = { "2x", "3x", "4x", "5x", "6x", "7x", "8x", "9x", "10x" }

local ZOOM_VALUES = { 2, 3, 4, 5, 6, 7, 8 }
local ZOOM_STRINGS = { "2x", "3x", "4x", "5x", "6x", "7x", "8x" }

local ZOOM_SPEED_VALUES = { 0, 0.75, 1.5, 3, 5, 10, 15 }
local ZOOM_SPEED_STRINGS = { "Instant", "Very Slow", "Slow", "Medium", "Fast", "Very Fast", "Ultra Fast" }

local LEAN_VALUES = { 5, 10, 15, 20, 25, 30, 35, 40, 45 }
local LEAN_STRINGS = { "5°", "10°", "15°", "20°", "25°", "30°", "35°", "40°", "45°" }

-- SETTINGS DEFINITIONS
CameraSettings.SETTINGS = {}

CameraSettings.SETTINGS.cameraMoveSpeed = {
    ['default'] = 8,
    ['serverOnly'] = false,
    ['values'] = SPEED_VALUES,
    ['strings'] = SPEED_STRINGS
}

CameraSettings.SETTINGS.cameraSprintMultiplier = {
    ['default'] = 3,
    ['serverOnly'] = false,
    ['values'] = SPRINT_VALUES,
    ['strings'] = SPRINT_STRINGS
}

CameraSettings.SETTINGS.cameraZoomMultiplier = {
    ['default'] = 3,
    ['serverOnly'] = false,
    ['values'] = ZOOM_VALUES,
    ['strings'] = ZOOM_STRINGS
}

CameraSettings.SETTINGS.cameraZoomSpeed = {
    ['default'] = 5,
    ['serverOnly'] = false,
    ['values'] = ZOOM_SPEED_VALUES,
    ['strings'] = ZOOM_SPEED_STRINGS
}

CameraSettings.SETTINGS.cameraLeanAngle = {
    ['default'] = 20,
    ['serverOnly'] = false,
    ['values'] = LEAN_VALUES,
    ['strings'] = LEAN_STRINGS
}

CameraSettings.SETTINGS.cameraSpeedPreset1 = {
    ['default'] = 0.5,
    ['serverOnly'] = false,
    ['values'] = SPEED_VALUES,
    ['strings'] = SPEED_STRINGS
}

CameraSettings.SETTINGS.cameraSpeedPreset2 = {
    ['default'] = 1,
    ['serverOnly'] = false,
    ['values'] = SPEED_VALUES,
    ['strings'] = SPEED_STRINGS
}

CameraSettings.SETTINGS.cameraSpeedPreset3 = {
    ['default'] = 10,
    ['serverOnly'] = false,
    ['values'] = SPEED_VALUES,
    ['strings'] = SPEED_STRINGS
}

CameraSettings.SETTINGS.cameraSpeedPreset4 = {
    ['default'] = 15,
    ['serverOnly'] = false,
    ['values'] = SPEED_VALUES,
    ['strings'] = SPEED_STRINGS
}

-- Current settings (stored locally, no network sync needed)
CameraSettings.settings = {
    cameraMoveSpeed = 8,
    cameraSprintMultiplier = 3,
    cameraZoomMultiplier = 3,
    cameraZoomSpeed = 5,
    cameraLeanAngle = 20,
    cameraSpeedPreset1 = 0.5,
    cameraSpeedPreset2 = 1,
    cameraSpeedPreset3 = 10,
    cameraSpeedPreset4 = 15
}

-- Apply a speed preset
function CameraSettings.applyPreset(presetNumber)
    local presetKey = "cameraSpeedPreset" .. presetNumber
    local presetSpeed = CameraSettings.settings[presetKey]
    
    if presetSpeed then
        CameraSettings.settings.cameraMoveSpeed = presetSpeed
        CameraSettings.writeSettings()
        print(string.format("[Free Camera] Applied Preset %d: %.1f m/s", presetNumber, presetSpeed))
        
        -- Update menu control if it exists
        if CameraSettings.CONTROLS['cameraMoveSpeed'] then
            local newIndex = CameraSettings.getStateIndex('cameraMoveSpeed', presetSpeed)
            CameraSettings.CONTROLS['cameraMoveSpeed']:setState(newIndex)
        end
    end
end

-- Helper function to get next/previous speed value
function CameraSettings.adjustSpeed(direction)
    local currentSpeed = CameraSettings.settings.cameraMoveSpeed
    local values = CameraSettings.SETTINGS.cameraMoveSpeed.values
    local currentIndex = CameraSettings.getStateIndex('cameraMoveSpeed', currentSpeed)
    
    local newIndex = currentIndex + direction
    newIndex = math.max(1, math.min(#values, newIndex))
    
    if newIndex ~= currentIndex then
        CameraSettings.settings.cameraMoveSpeed = values[newIndex]
        CameraSettings.writeSettings()
        print(string.format("[Free Camera] Speed: %.1f m/s", CameraSettings.settings.cameraMoveSpeed))
        
        -- Update menu control if it exists
        if CameraSettings.CONTROLS['cameraMoveSpeed'] then
            CameraSettings.CONTROLS['cameraMoveSpeed']:setState(newIndex)
        end
    end
end

function CameraSettings.getStateIndex(id, value)
    local value = value or CameraSettings.settings[id]
    local values = CameraSettings.SETTINGS[id].values
    if type(value) == 'number' then
        local index = CameraSettings.SETTINGS[id].default
        local initialdiff = math.huge
        for i, v in pairs(values) do
            local currentdiff = math.abs(v - value)
            if currentdiff < initialdiff then
                initialdiff = currentdiff
                index = i
            end
        end
        return index
    else
        for i, v in pairs(values) do
            if value == v then
                return i
            end
        end
    end
    return CameraSettings.SETTINGS[id].default
end

-- READ/WRITE SETTINGS
function CameraSettings.writeSettings()
    local key = "freeCamera"
    local userSettingsFile = Utils.getFilename("modSettings/FarmHandTools.xml", getUserProfileAppPath())
    
    local xmlFile = createXMLFile("settings", userSettingsFile, key)
    if xmlFile ~= 0 then
        
        local function setXmlValue(id)
            if not id or not CameraSettings.SETTINGS[id] then
                return
            end
            
            local xmlValueKey = "freeCamera." .. id .. "#value"
            local value = CameraSettings.settings[id]
            if type(value) == 'number' then
                setXMLFloat(xmlFile, xmlValueKey, value)
            elseif type(value) == 'boolean' then
                setXMLBool(xmlFile, xmlValueKey, value)
            end
        end
        
        for _, id in pairs(CameraSettings.menuItems) do
            setXmlValue(id)
        end
        
        saveXMLFile(xmlFile)
        delete(xmlFile)
    end
end

function CameraSettings.readSettings()
    local userSettingsFile = Utils.getFilename("modSettings/FarmHandTools.xml", getUserProfileAppPath())
    
    if not fileExists(userSettingsFile) then
        CameraSettings.writeSettings()
        return
    end
    
    local xmlFile = loadXMLFile("freeCamera", userSettingsFile)
    if xmlFile ~= 0 then
        
        local function getXmlValue(id)
            local setting = CameraSettings.SETTINGS[id]
            if setting then
                local xmlValueKey = "freeCamera." .. id .. "#value"
                local value = CameraSettings.settings[id]
                local value_string = tostring(value)
                if hasXMLProperty(xmlFile, xmlValueKey) then
                    
                    if type(value) == 'number' then
                        value = getXMLFloat(xmlFile, xmlValueKey) or value
                        
                        if value == math.floor(value) then
                            value_string = tostring(value)
                        else
                            value_string = string.format("%.3f", value)
                        end
                        
                    elseif type(value) == 'boolean' then
                        value = getXMLBool(xmlFile, xmlValueKey) or false
                        value_string = tostring(value)
                    end
                    
                    CameraSettings.settings[id] = value
                    return value_string
                end
            end
            return "MISSING"
        end
        
        print("[FarmHandTools] CAMERA SETTINGS")
        for _, id in pairs(CameraSettings.menuItems) do
            local valueString = getXmlValue(id)
            print("  " .. id .. ": " .. valueString)
        end
        
        delete(xmlFile)
    end
end

CameraSettingsControls = {}
function CameraSettingsControls.onMenuOptionChanged(self, state, menuOption)
    local id = menuOption.id
    local setting = CameraSettings.SETTINGS
    local value = setting[id].values[state]

    if value ~= nil then
        CameraSettings.settings[id] = value
        
        -- Save settings to disk
        CameraSettings.writeSettings()
    end
end

local function updateFocusIds(element)
    if not element then
        return
    end
    element.focusId = FocusManager:serveAutoFocusId()
    for _, child in pairs(element.elements) do
        updateFocusIds(child)
    end
end

function CameraSettings.addSettingsToMenu()
    local inGameMenu = g_gui.screenControllers[InGameMenu]
    local settingsPage = inGameMenu.pageSettings
    -- The name is required as otherwise the focus manager would ignore any control which has CameraSettings as a callback target
    CameraSettingsControls.name = settingsPage.name

    function CameraSettings.addMultiMenuOption(id)
        local callback = "onMenuOptionChanged"
        local i18n_title = "setting_camera_" .. id
        local i18n_tooltip = "setting_camera_" .. id .. "_tooltip"
        local options = CameraSettings.SETTINGS[id].strings

        local originalBox = settingsPage.multiVolumeVoiceBox

        local menuOptionBox = originalBox:clone(settingsPage.gameSettingsLayout)
        menuOptionBox.id = id .. "box"

        local menuMultiOption = menuOptionBox.elements[1]
        menuMultiOption.id = id
        menuMultiOption.target = CameraSettingsControls

        menuMultiOption:setCallback("onClickCallback", callback)
        menuMultiOption:setDisabled(false)

        local toolTip = menuMultiOption.elements[1]
        toolTip:setText(g_i18n:getText(i18n_tooltip))

        local setting = menuOptionBox.elements[2]
        setting:setText(g_i18n:getText(i18n_title))

        menuMultiOption:setTexts({ table.unpack(options) })
        menuMultiOption:setState(CameraSettings.getStateIndex(id))

        CameraSettings.CONTROLS[id] = menuMultiOption

        -- Assign new focus IDs to the controls as clone() copies the existing ones which are supposed to be unique
        updateFocusIds(menuOptionBox)
        table.insert(settingsPage.controlsList, menuOptionBox)
        return menuOptionBox
    end

    -- Add section
    local sectionTitle = nil
    for idx, elem in ipairs(settingsPage.gameSettingsLayout.elements) do
        if elem.name == "sectionHeader" then
            sectionTitle = elem:clone(settingsPage.gameSettingsLayout)
            break
        end
    end

    if sectionTitle then
        sectionTitle:setText(g_i18n:getText("setting_camera_section"))
    else
        sectionTitle = TextElement.new()
        sectionTitle:applyProfile("fs25_settingsSectionHeader", true)
        sectionTitle:setText(g_i18n:getText("setting_camera_section"))
        sectionTitle.name = "sectionHeader"
        settingsPage.gameSettingsLayout:addElement(sectionTitle)
    end
    -- Apply a new focus ID in either case
    sectionTitle.focusId = FocusManager:serveAutoFocusId()
    table.insert(settingsPage.controlsList, sectionTitle)
    CameraSettings.CONTROLS[sectionTitle.name] = sectionTitle

    for _, id in pairs(CameraSettings.menuItems) do
        CameraSettings.addMultiMenuOption(id)
    end

    settingsPage.gameSettingsLayout:invalidateLayout()

    -- ENABLE/DISABLE OPTIONS FOR CLIENTS
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
        for _, id in pairs(CameraSettings.menuItems) do
            local menuOption = CameraSettings.CONTROLS[id]
            menuOption:setState(CameraSettings.getStateIndex(id))

            if CameraSettings.SETTINGS[id].disabled then
                menuOption:setDisabled(true)
            else
                menuOption:setDisabled(false)
            end
        end
    end)
end

-- Allow keyboard navigation of menu options
FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
    if gui == "ingameMenuSettings" then
        -- Let the focus manager know about our custom controls now
        for _, control in pairs(CameraSettings.CONTROLS) do
            if not control.focusId or not FocusManager.currentFocusData.idToElementMapping[control.focusId] then
                if not FocusManager:loadElementFromCustomValues(control, nil, nil, false, false) then
                    print(
                        "Could not register control %s with the focus manager. Selecting the control might be bugged",
                        control.id or control.name or control.focusId)
                end
            end
        end
        -- Invalidate the layout so the up/down connections are analyzed again
        local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
        settingsPage.gameSettingsLayout:invalidateLayout()
    end
end)

-- Initialize settings menu when mission loads
Mission00.load = Utils.appendedFunction(Mission00.load, function()
    -- Load settings from disk first
    CameraSettings.readSettings()
    
    -- Then add menu controls
    CameraSettings.addSettingsToMenu()
end)
