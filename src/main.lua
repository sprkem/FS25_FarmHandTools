FarmHandTools = {}

function FarmHandTools:loadMap()
    g_currentMission.FarmHandTools = self

    -- Create the free camera instance
    self.freeCamera = FreeCamera.new()

    print("FarmHandTools: Loaded - Press Right Ctrl+P to toggle free camera")
end

function FarmHandTools:delete()
    if self.freeCamera ~= nil then
        self.freeCamera:delete()
        self.freeCamera = nil
    end
end

-- function FarmHandTools:update(dt)
--     -- Free camera update is now handled by the hooked PlayerInputComponent:update
-- end

-- Function called when Right Ctrl+P is pressed
function FarmHandTools.toggleFreeCamera()
    if g_currentMission.FarmHandTools ~= nil and g_currentMission.FarmHandTools.freeCamera ~= nil then
        g_currentMission.FarmHandTools.freeCamera:toggle()
    end
end

function FarmHandTools.onSpeedUp()
    if g_currentMission.FarmHandTools ~= nil and
        g_currentMission.FarmHandTools.freeCamera ~= nil and
        g_currentMission.FarmHandTools.freeCamera.isActive then
        CameraSettings.adjustSpeed(1)
    end
end

function FarmHandTools.onSpeedDown()
    if g_currentMission.FarmHandTools ~= nil and
        g_currentMission.FarmHandTools.freeCamera ~= nil and
        g_currentMission.FarmHandTools.freeCamera.isActive then
        CameraSettings.adjustSpeed(-1)
    end
end

function FarmHandTools.onPreset1()
    if g_currentMission.FarmHandTools ~= nil and
        g_currentMission.FarmHandTools.freeCamera ~= nil and
        g_currentMission.FarmHandTools.freeCamera.isActive then
        CameraSettings.applyPreset(1)
    end
end

function FarmHandTools.onPreset2()
    if g_currentMission.FarmHandTools ~= nil and
        g_currentMission.FarmHandTools.freeCamera ~= nil and
        g_currentMission.FarmHandTools.freeCamera.isActive then
        CameraSettings.applyPreset(2)
    end
end

function FarmHandTools.onPreset3()
    if g_currentMission.FarmHandTools ~= nil and
        g_currentMission.FarmHandTools.freeCamera ~= nil and
        g_currentMission.FarmHandTools.freeCamera.isActive then
        CameraSettings.applyPreset(3)
    end
end

function FarmHandTools.onPreset4()
    if g_currentMission.FarmHandTools ~= nil and
        g_currentMission.FarmHandTools.freeCamera ~= nil and
        g_currentMission.FarmHandTools.freeCamera.isActive then
        CameraSettings.applyPreset(4)
    end
end

-- Hook into PlayerInputComponent:update to feed inputs to free camera
local function playerInputComponentUpdate(self, superFunc, dt)
    -- If free camera is active, skip normal player input processing
    if g_currentMission.FarmHandTools ~= nil and
        g_currentMission.FarmHandTools.freeCamera ~= nil and
        g_currentMission.FarmHandTools.freeCamera.isActive then
        -- Update free camera with our input component BEFORE clearing values
        g_currentMission.FarmHandTools.freeCamera:update(dt, self)

        -- Then clear all input values to prevent any player movement
        self.moveForward = 0
        self.moveRight = 0
        self.walkAxis = 0
        self.runAxis = 0
        self.cameraRotationX = 0
        self.cameraRotationY = 0
    else
        -- Call original update when free camera is not active
        superFunc(self, dt)
    end
end

-- Block vehicle switching when free camera is active
local function onInputSwitchVehicle(self, superFunc, actionName, inputValue, callbackState, isAnalog, isMouse,
                                    deviceCategory, binding)
    if g_currentMission.FarmHandTools ~= nil and
        g_currentMission.FarmHandTools.freeCamera ~= nil and
        g_currentMission.FarmHandTools.freeCamera.isActive then
        return
    end
    return superFunc(self, actionName, inputValue, callbackState, isAnalog, isMouse, deviceCategory, binding)
end

-- Hook into player action events to register our keybinds
local function addPlayerActionEvents(self, superFunc, ...)
    superFunc(self, ...)

    local _, id = g_inputBinding:registerActionEvent(
        InputAction.FREE_CAMERA_TOGGLE,
        self,
        FarmHandTools.toggleFreeCamera,
        false, -- triggerUp
        true,  -- triggerDown
        false, -- triggerAlways
        true   -- startActive
    )
    g_inputBinding:setActionEventTextVisibility(id, false)

    -- Register speed controls globally
    _, id = g_inputBinding:registerActionEvent(
        InputAction.FREE_CAMERA_SPEED_UP,
        self,
        FarmHandTools.onSpeedUp,
        false,
        true,
        false,
        true
    )
    g_inputBinding:setActionEventTextVisibility(id, false)

    _, id = g_inputBinding:registerActionEvent(
        InputAction.FREE_CAMERA_SPEED_DOWN,
        self,
        FarmHandTools.onSpeedDown,
        false,
        true,
        false,
        true
    )
    g_inputBinding:setActionEventTextVisibility(id, false)

    -- Register preset speed controls
    _, id = g_inputBinding:registerActionEvent(
        InputAction.FREE_CAMERA_PRESET_1,
        self,
        FarmHandTools.onPreset1,
        false,
        true,
        false,
        true
    )
    g_inputBinding:setActionEventTextVisibility(id, false)

    _, id = g_inputBinding:registerActionEvent(
        InputAction.FREE_CAMERA_PRESET_2,
        self,
        FarmHandTools.onPreset2,
        false,
        true,
        false,
        true
    )
    g_inputBinding:setActionEventTextVisibility(id, false)

    _, id = g_inputBinding:registerActionEvent(
        InputAction.FREE_CAMERA_PRESET_3,
        self,
        FarmHandTools.onPreset3,
        false,
        true,
        false,
        true
    )
    g_inputBinding:setActionEventTextVisibility(id, false)

    _, id = g_inputBinding:registerActionEvent(
        InputAction.FREE_CAMERA_PRESET_4,
        self,
        FarmHandTools.onPreset4,
        false,
        true,
        false,
        true
    )
    g_inputBinding:setActionEventTextVisibility(id, false)
end

-- Apply hooks using the proper pattern
PlayerInputComponent.update = Utils.overwrittenFunction(
    PlayerInputComponent.update,
    playerInputComponentUpdate
)

PlayerInputComponent.onInputSwitchVehicle = Utils.overwrittenFunction(
    PlayerInputComponent.onInputSwitchVehicle,
    onInputSwitchVehicle
)

PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.overwrittenFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents,
    addPlayerActionEvents
)

-- Register as mod event listener
addModEventListener(FarmHandTools)
