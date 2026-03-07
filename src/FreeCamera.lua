---@class FreeCamera
FreeCamera = {}
local FreeCamera_mt = Class(FreeCamera)

-- Default constants (overridden by CameraSettings)
FreeCamera.BASE_MOVE_SPEED = 8 -- meters per second (default, overridden by settings)
FreeCamera.SPRINT_MULTIPLIER = 3.0 -- (default, overridden by settings)
FreeCamera.SLOW_MULTIPLIER = 0.3
FreeCamera.BASE_FOV = 60 -- degrees
FreeCamera.DEFAULT_ZOOM_MULTIPLIER = 3
FreeCamera.DEFAULT_LEAN_ANGLE = 20 -- degrees
FreeCamera.LEAN_SPEED = 3.0 -- time factor for lerping (higher = faster)
FreeCamera.LEAN_OFFSET_MULTIPLIER = 0.8 -- how much to offset position when leaning

function FreeCamera.new()
    local self = setmetatable({}, FreeCamera_mt)

    self.isActive = false
    self.camera = nil
    self.cameraNode = nil
    self.originalCameraNode = nil

    -- Position and rotation
    self.posX = 0
    self.posY = 0
    self.posZ = 0
    self.rotX = 0 -- pitch
    self.rotY = 0 -- yaw

    -- Input tracking for vertical movement
    self.upInput = 0
    self.downInput = 0
    self.upEventId = nil
    self.downEventId = nil

    -- Zoom state
    self.isZoomed = false
    self.baseFOV = math.rad(FreeCamera.BASE_FOV)
    self.currentFOV = self.baseFOV
    self.targetFOV = self.baseFOV
    self.zoomInput = 0
    self.zoomEventId = nil

    -- Lean state
    self.currentLeanRoll = 0
    self.targetLeanRoll = 0
    self.leanLeftInput = 0
    self.leanRightInput = 0
    self.leanLeftEventId = nil
    self.leanRightEventId = nil

    return self
end

function FreeCamera:delete()
    if self.camera ~= nil then
        g_cameraManager:removeCamera(self.camera)
        delete(self.camera)
        self.camera = nil
    end

    if self.cameraNode ~= nil then
        delete(self.cameraNode)
        self.cameraNode = nil
    end
end

function FreeCamera:initialize()
    -- Create the camera node for positioning
    self.cameraNode = createTransformGroup("freeCameraNode")
    link(getRootNode(), self.cameraNode)

    -- Create the actual camera with base FOV
    self.baseFOV = math.rad(FreeCamera.BASE_FOV)
    self.currentFOV = self.baseFOV
    self.targetFOV = self.baseFOV
    self.camera = createCamera("freeCamera", self.baseFOV, 0.15, 6000)
    link(self.cameraNode, self.camera)

    -- Register with camera manager
    g_cameraManager:addCamera(self.camera, nil, false)
end

function FreeCamera:activate()
    if self.isActive then
        return
    end

    if self.camera == nil then
        self:initialize()
    end

    -- Store the original camera node (this is just a number/node ID)
    self.originalCameraNode = g_cameraManager:getActiveCamera()

    -- Get the exact position and rotation from the active camera node
    if self.originalCameraNode ~= nil then
        -- First try to get from player camera object if available
        local player = g_currentMission.player
        if player ~= nil and player.camera ~= nil and player.camera.getCameraPosition ~= nil then
            -- Use PlayerCamera methods
            self.posX, self.posY, self.posZ = player.camera:getCameraPosition()
            local pitch, yaw, _ = player.camera:getRotation()
            
            -- Negate pitch to match our coordinate system
            self.rotX = -pitch
            self.rotY = yaw
        else
            -- Fallback: get position directly from the camera node
            self.posX, self.posY, self.posZ = getWorldTranslation(self.originalCameraNode)
            self.rotX, self.rotY, _ = getWorldRotation(self.originalCameraNode)
        end

        print(string.format("Free Camera: Starting position: %.2f, %.2f, %.2f | rotation: %.2f, %.2f",
            self.posX, self.posY, self.posZ, math.deg(self.rotX), math.deg(self.rotY)))

        self:updateTransform()
    end

    -- Activate the free camera
    g_cameraManager:setActiveCamera(self.camera)
    self.isActive = true

    -- Register action events for vertical movement
    self:registerActionEvents()

    print("Free Camera: ACTIVATED - WASD: move, Q/E: up/down, +/-: speed, Mouse: look")
end

function FreeCamera:registerActionEvents()
    -- Register separate UP and DOWN actions (supports both keyboard and controller)
    local _, eventId = g_inputBinding:registerActionEvent(InputAction.FREE_CAMERA_UP, self, self.onInputUp, false, false,
        true, true)
    self.upEventId = eventId
    
    _, eventId = g_inputBinding:registerActionEvent(InputAction.FREE_CAMERA_DOWN, self, self.onInputDown, false, false,
        true, true)
    self.downEventId = eventId

    -- Register zoom action
    _, eventId = g_inputBinding:registerActionEvent(InputAction.FREE_CAMERA_ZOOM, self, self.onInputZoom, false, false,
        true, true)
    self.zoomEventId = eventId

    -- Register lean actions (same parameters as UP/DOWN which work correctly)
    _, eventId = g_inputBinding:registerActionEvent(InputAction.FREE_CAMERA_LEAN_LEFT, self, self.onInputLeanLeft, false, false,
        true, true)
    self.leanLeftEventId = eventId

    _, eventId = g_inputBinding:registerActionEvent(InputAction.FREE_CAMERA_LEAN_RIGHT, self, self.onInputLeanRight, false, false,
        true, true)
    self.leanRightEventId = eventId
end

function FreeCamera:unregisterActionEvents()
    if self.upEventId ~= nil then
        g_inputBinding:removeActionEvent(self.upEventId)
        self.upEventId = nil
    end
    if self.downEventId ~= nil then
        g_inputBinding:removeActionEvent(self.downEventId)
        self.downEventId = nil
    end
    if self.zoomEventId ~= nil then
        g_inputBinding:removeActionEvent(self.zoomEventId)
        self.zoomEventId = nil
    end
    if self.leanLeftEventId ~= nil then
        g_inputBinding:removeActionEvent(self.leanLeftEventId)
        self.leanLeftEventId = nil
    end
    if self.leanRightEventId ~= nil then
        g_inputBinding:removeActionEvent(self.leanRightEventId)
        self.leanRightEventId = nil
    end
end

function FreeCamera:onInputUp(actionName, inputValue, callbackState, isAnalog)
    self.upInput = inputValue
end

function FreeCamera:onInputDown(actionName, inputValue, callbackState, isAnalog)
    self.downInput = inputValue
end

function FreeCamera:onInputZoom(actionName, inputValue, callbackState, isAnalog)
    self.zoomInput = inputValue
    self:updateZoom()
end

function FreeCamera:onInputLeanLeft(actionName, inputValue, callbackState, isAnalog)
    self.leanLeftInput = inputValue or 0
    if self.leanLeftInput < 0.01 then
        self.leanLeftInput = 0
    end
end

function FreeCamera:onInputLeanRight(actionName, inputValue, callbackState, isAnalog)
    self.leanRightInput = inputValue or 0
    if self.leanRightInput < 0.01 then
        self.leanRightInput = 0
    end
end

function FreeCamera:updateZoom()
    if self.camera == nil then
        return
    end

    local isZooming = self.zoomInput > 0.5
    
    if isZooming ~= self.isZoomed then
        self.isZoomed = isZooming
        
        if self.isZoomed then
            -- Zoom in: divide FOV by zoom multiplier
            local zoomMultiplier = CameraSettings and CameraSettings.settings.cameraZoomMultiplier or FreeCamera.DEFAULT_ZOOM_MULTIPLIER
            self.targetFOV = self.baseFOV / zoomMultiplier
        else
            -- Zoom out: restore base FOV
            self.targetFOV = self.baseFOV
        end
    end
end

function FreeCamera:updateLean()
    -- Calculate target lean based on input
    local leanAngle = CameraSettings and CameraSettings.settings.cameraLeanAngle or FreeCamera.DEFAULT_LEAN_ANGLE
    local leanAngleRad = math.rad(leanAngle)
    
    -- Clean up input values below threshold
    local leftInput = (self.leanLeftInput or 0)
    local rightInput = (self.leanRightInput or 0)
    
    -- Force values below threshold to 0
    if leftInput < 0.01 then leftInput = 0 end
    if rightInput < 0.01 then rightInput = 0 end
    
    -- Calculate target based on current input state
    if leftInput > 0 then
        self.targetLeanRoll = leanAngleRad  -- Positive for left lean
    elseif rightInput > 0 then
        self.targetLeanRoll = -leanAngleRad   -- Negative for right lean
    else
        -- No lean input, return to neutral
        self.targetLeanRoll = 0
    end
end

function FreeCamera:deactivate()
    if not self.isActive then
        return
    end

    -- Unregister action events
    self:unregisterActionEvents()

    -- Reset zoom state
    self.isZoomed = false
    self.zoomInput = 0
    self.targetFOV = self.baseFOV
    self.currentFOV = self.baseFOV
    if self.camera ~= nil then
        setFovY(self.camera, self.baseFOV)
    end

    -- Reset lean state
    self.currentLeanRoll = 0
    self.targetLeanRoll = 0
    self.leanLeftInput = 0
    self.leanRightInput = 0

    -- Restore original camera
    if self.originalCameraNode ~= nil then
        g_cameraManager:setActiveCamera(self.originalCameraNode)
        self.originalCameraNode = nil
    end

    self.isActive = false

    print("Free Camera: DEACTIVATED")
end

function FreeCamera:toggle()
    if self.isActive then
        self:deactivate()
    else
        self:activate()
    end
end

function FreeCamera:updateTransform()
    if self.cameraNode == nil then
        return
    end

    -- Calculate lean offset (arc to side and lower)
    local leanPercent = self.currentLeanRoll / math.rad(45)  -- Normalize to -1 to 1
    local offsetMultiplier = FreeCamera.LEAN_OFFSET_MULTIPLIER
    
    -- Right vector for lateral offset
    local rightX = math.cos(self.rotY)
    local rightZ = -math.sin(self.rotY)
    
    -- Apply lateral offset (invert direction: positive lean = left, negative lean = right)
    local leanOffsetX = -rightX * leanPercent * offsetMultiplier
    local leanOffsetZ = -rightZ * leanPercent * offsetMultiplier
    
    -- Apply vertical offset (lower when leaning)
    local leanOffsetY = -math.abs(leanPercent) * offsetMultiplier * 0.3

    -- Set position with lean offset
    setTranslation(self.cameraNode, 
        self.posX + leanOffsetX, 
        self.posY + leanOffsetY, 
        self.posZ + leanOffsetZ)

    -- Set rotation (pitch, yaw, roll with lean)
    setRotation(self.cameraNode, self.rotX, self.rotY, self.currentLeanRoll)
end

function FreeCamera:update(dt, inputComponent)
    if not self.isActive then
        return
    end

    -- Use the player's input component (passed from our hook)
    if inputComponent == nil then
        return
    end

    -- Camera rotation from mouse
    local cameraSensitivity = g_gameSettings:getValue(GameSettings.SETTING.CAMERA_SENSITIVITY)
    local rotDeltaX = -inputComponent.cameraRotationX * cameraSensitivity -- Pitch (inverted)
    local rotDeltaY = -inputComponent.cameraRotationY * cameraSensitivity -- Yaw (inverted)

    self.rotX = math.clamp(self.rotX + rotDeltaX, -math.pi / 2, math.pi / 2)
    self.rotY = self.rotY + rotDeltaY

    -- Apply movement
    local dtSeconds = dt / 1000.0
    -- Use settings values if available, otherwise fall back to class defaults
    local moveSpeed = CameraSettings and CameraSettings.settings.cameraMoveSpeed or FreeCamera.BASE_MOVE_SPEED

    -- Check if sprint is held (for faster movement)
    if inputComponent.runAxis > 0.5 then
        local sprintMultiplier = CameraSettings and CameraSettings.settings.cameraSprintMultiplier or FreeCamera.SPRINT_MULTIPLIER
        moveSpeed = moveSpeed * sprintMultiplier
    end

    -- Calculate movement relative to camera's rotation
    local moveForward = -inputComponent.moveForward -- Negative because game uses inverted forward
    local moveRight = inputComponent.moveRight

    -- Camera's forward direction (based on yaw only, ignore pitch for horizontal movement)
    local forwardX = math.sin(self.rotY)
    local forwardZ = math.cos(self.rotY)

    -- Camera's right direction
    local rightX = math.cos(self.rotY)
    local rightZ = -math.sin(self.rotY)

    -- Combine forward and strafe movement
    local moveX = forwardX * moveForward + rightX * moveRight
    local moveZ = forwardZ * moveForward + rightZ * moveRight

    -- Apply movement
    self.posX = self.posX + moveX * moveSpeed * dtSeconds
    self.posZ = self.posZ + moveZ * moveSpeed * dtSeconds

    -- Vertical movement using separate up/down inputs
    local verticalAxis = self.upInput - self.downInput
    self.posY = self.posY + verticalAxis * moveSpeed * dtSeconds

    -- Clamp Y position to reasonable values
    local terrainHeight = getTerrainHeightAtWorldPos(g_terrainNode, self.posX, self.posY, self.posZ)
    self.posY = math.max(terrainHeight + 0.5, self.posY)
    self.posY = math.min(1000, self.posY) -- Max altitude

    -- Update lean target based on current input state (recalculate every frame)
    self:updateLean()

    -- Smoothly interpolate lean roll
    local lerpFactor = 1 - math.pow(0.5, dtSeconds * FreeCamera.LEAN_SPEED)
    self.currentLeanRoll = self.currentLeanRoll + (self.targetLeanRoll - self.currentLeanRoll) * lerpFactor

    -- Smoothly interpolate zoom FOV
    local zoomSpeed = CameraSettings and CameraSettings.settings.cameraZoomSpeed or 5
    if zoomSpeed == 0 then
        -- Instant zoom
        self.currentFOV = self.targetFOV
    else
        -- Smooth zoom
        local zoomLerpFactor = 1 - math.pow(0.5, dtSeconds * zoomSpeed)
        self.currentFOV = self.currentFOV + (self.targetFOV - self.currentFOV) * zoomLerpFactor
    end
    
    -- Apply the current FOV to the camera
    if self.camera ~= nil then
        setFovY(self.camera, self.currentFOV)
    end

    -- Update the camera transform
    self:updateTransform()
end
