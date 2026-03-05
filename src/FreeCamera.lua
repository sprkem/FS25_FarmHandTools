---@class FreeCamera
FreeCamera = {}
local FreeCamera_mt = Class(FreeCamera)

FreeCamera.BASE_MOVE_SPEED = 10 -- meters per second
FreeCamera.SPRINT_MULTIPLIER = 3.0
FreeCamera.SLOW_MULTIPLIER = 0.3

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
    
    -- Input tracking for Q/E keys
    self.upInput = 0
    self.downInput = 0
    self.upEventId = nil
    self.downEventId = nil
    
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
    
    -- Create the actual camera
    self.camera = createCamera("freeCamera", math.rad(60), 0.15, 6000)
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
            self.rotX, self.rotY, _ = player.camera:getRotation()
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
    
    -- Disable player physics so they don't fall/move
    if g_currentMission.player ~= nil then
        g_currentMission.player.mover:disablePhysics()
    end
    
    -- Register action events for Q/E
    self:registerActionEvents()
    
    print("Free Camera: ACTIVATED - Use WASD to move, Q/E for up/down, Mouse to look")
end

function FreeCamera:registerActionEvents()
    -- Register Q/E for vertical movement
    local _, eventId = g_inputBinding:registerActionEvent(InputAction.FREE_CAMERA_UP, self, self.onInputUp, false, false, true, true)
    self.upEventId = eventId
    
    _, eventId = g_inputBinding:registerActionEvent(InputAction.FREE_CAMERA_DOWN, self, self.onInputDown, false, false, true, true)
    self.downEventId = eventId
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
end

function FreeCamera:onInputUp(actionName, inputValue, callbackState, isAnalog)
    self.upInput = inputValue
end

function FreeCamera:onInputDown(actionName, inputValue, callbackState, isAnalog)
    self.downInput = inputValue
end

function FreeCamera:deactivate()
    if not self.isActive then
        return
    end
    
    -- Unregister action events
    self:unregisterActionEvents()
    
    -- Restore original camera
    if self.originalCameraNode ~= nil then
        g_cameraManager:setActiveCamera(self.originalCameraNode)
        self.originalCameraNode = nil
    end
    
    self.isActive = false
    
    -- Re-enable player physics
    if g_currentMission.player ~= nil then
        g_currentMission.player.mover:enablePhysics()
    end
    
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
    
    -- Set position
    setTranslation(self.cameraNode, self.posX, self.posY, self.posZ)
    
    -- Set rotation (pitch, yaw, roll)
    setRotation(self.cameraNode, self.rotX, self.rotY, 0)
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
    local rotDeltaX = -inputComponent.cameraRotationX * cameraSensitivity  -- Pitch (inverted)
    local rotDeltaY = -inputComponent.cameraRotationY * cameraSensitivity  -- Yaw (inverted)
    
    self.rotX = math.clamp(self.rotX + rotDeltaX, -math.pi/2, math.pi/2)
    self.rotY = self.rotY + rotDeltaY
    
    -- Apply movement
    local dtSeconds = dt / 1000.0
    local moveSpeed = FreeCamera.BASE_MOVE_SPEED
    
    -- Check if sprint is held (for faster movement)
    if inputComponent.runAxis > 0.5 then
        moveSpeed = moveSpeed * FreeCamera.SPRINT_MULTIPLIER
    end
    
    -- Calculate movement relative to camera's rotation
    local moveForward = -inputComponent.moveForward  -- Negative because game uses inverted forward
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
    
    -- Vertical movement using Q/E keys
    local verticalAxis = self.upInput - self.downInput
    
    self.posY = self.posY + verticalAxis * moveSpeed * dtSeconds
    
    -- Clamp Y position to reasonable values
    local terrainHeight = getTerrainHeightAtWorldPos(g_terrainNode, self.posX, self.posY, self.posZ)
    self.posY = math.max(terrainHeight + 0.5, self.posY)
    self.posY = math.min(1000, self.posY) -- Max altitude
    
    -- Update the camera transform
    self:updateTransform()
end

function FreeCamera:draw()
    if not self.isActive then
        return
    end
    
    -- Draw on-screen help text
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextColor(1, 1, 1, 1)
    setTextBold(false)
    
    local textSize = 0.015
    local x = 0.02
    local y = 0.95
    
    renderText(x, y, textSize, "FREE CAMERA MODE")
    y = y - textSize * 1.5
    renderText(x, y, textSize * 0.8, "WASD: Move | Q/E: Up/Down | Mouse: Look | Right Ctrl+P: Exit")
    
    -- Draw position info
    y = y - textSize * 1.2
    renderText(x, y, textSize * 0.7, string.format("Position: %.1f, %.1f, %.1f", self.posX, self.posY, self.posZ))
end