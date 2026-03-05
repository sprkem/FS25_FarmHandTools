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

-- Hook into player action events to register our keybind
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

    -- Hide the action text from screen
    g_inputBinding:setActionEventTextVisibility(id, false)
end

-- Apply hooks using the proper pattern
PlayerInputComponent.update = Utils.overwrittenFunction(
    PlayerInputComponent.update,
    playerInputComponentUpdate
)

PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.overwrittenFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents,
    addPlayerActionEvents
)

-- Register as mod event listener
addModEventListener(FarmHandTools)
