Script.Require('GameState.lua')

Bomber = 
{
    gravity = -9.8,
    kDefaultMoveSpeed = 3.5,
    kMaxPowerupStacks = 5,
}

function Bomber:Create()

    self.bomberId = 1

    self:Reset()
end

function Bomber:Reset()

    self.moveDir = Vec(0,0,0)
    self.moveVelocity = Vec(0,0,0)
    self.velocity = Vec(0,0,0)
    self.cellX = 0
    self.cellZ = 0
    self.actionTime = 0.0
    self.netYaw = 0.0
    self.netPosition = Vec()
    self.curMoveSpeed = 0
    self.swingOverlaps = {}
    self.swingTimer = 0.0
    self.placedBombs = 0
    self.alive = false

    self.moveSpeed = Bomber.kDefaultMoveSpeed
    self.bombCount = 1
    self.bombRange = 1

    self.bombPowerups = 0
    self.rangePowerups = 0 
    self.speedPowerups = 0

end

function Bomber:Start()

    self.mesh = self:FindChild('Mesh', true)
    self.camera = self:FindChild('Camera', true)
    self.swingSphere = self:FindChild('SwingSphere', true)
    
    if (self:IsLocallyControlled() and self.camera) then
        self.world:SetActiveCamera(self.camera)
    end

    self:OwnerChanged()

end

function Bomber:Stop()


end

function Bomber:GatherProperties()

    return
    {
        { name = "moveSpeed", type = DatumType.Float },
        { name = "bombScene", type = DatumType.Asset },
    }

end

function Bomber:GatherReplicatedData()

    return 
    {
        { name = 'netYaw', type = DatumType.Float },
        { name = 'netPosition', type = DatumType.Vector, onRep = 'OnRep_netPosition'},
        { name = 'curMoveSpeed', type = DatumType.Float },
        { name = 'bombCount', type = DatumType.Byte },
        { name = 'bombRange', type = DatumType.Byte },
        { name = 'moveSpeed', type = DatumType.Float },
    }

end

function Bomber:GatherNetFuncs()
    
    return 
    {
        { name = 'S_PlantBomb', type = NetFuncType.Server, reliable = true},
        { name = 'S_SwingCane', type = NetFuncType.Server, reliable = true},
        { name = 'S_SyncTransform', type = NetFuncType.Server, reliable = false},

        { name = "C_ForceWorldPosition", type = NetFuncType.Client, reliable = true},

        { name = 'M_SwingCane', type = NetFuncType.Multicast, reliable = false},
    }

end

function Bomber:BeginOverlap(this, other)

    if (this == self.swingSphere and other ~= self) then
        self.swingOverlaps[other] = other
    end

end

function Bomber:EndOverlap(this, other)

    if (this == self.swingSphere and other ~= self) then
        self.swingOverlaps[other] = nil
    end

end

function Bomber:OwnerChanged()
    
    self.justPossessed = true

    if ((not Network.IsLocal()) and self:HasStarted() and self:IsOwned()) then
        self:SetWorldPosition(self.netPosition)
        self.world:SetActiveCamera(self.camera)
    end

end

function Bomber:OnRep_netPosition()

    if (not self.netPositionSet) then
        self.netPositionSet = true

        if (self:IsOwned()) then
            self:SetWorldPosition(self.netPosition)
        end
    end

end

function Bomber:Tick(deltaTime)

    self:UpdateMovement(deltaTime)
    self:UpdateAction(deltaTime)
    self:UpdateMotion(deltaTime)
    self:UpdateAnimation(deltaTime)
    self:UpdateOrientation(deltaTime)
    self:UpdateCell(deltaTime)
    self:UpdateCamera(deltaTime)
    self:UpdateNetwork(deltaTime)

end

function Bomber:IsLocallyControlled()

    local locallyControlled = false
    if (Network.IsLocal()) then
        locallyControlled = (self.bomberId == 1)
    else
        locallyControlled = self:IsOwned()
    end

    return locallyControlled

end

function Bomber:IsBot()
    local owningHost = self:GetOwningHost()
    local isBot = (owningHost == NetHost.Invalid) and (self.bomberId ~= 1)

    return isBot
end

function Bomber:SetAlive(alive)

    if (alive) then
        self:Reset()
    end

    self:EnableCollision(alive)
    self:EnableOverlaps(alive)
    self:SetVisible(alive)

    self.alive = alive 

end

function Bomber:IsAlive()
    return self.alive
end

function Bomber:ForceWorldPosition(position)
    self:SetWorldPosition(position)
    self.netPosition = position
    self:InvokeNetFunc('C_ForceWorldPosition', position)
end

function Bomber:UpdateMovement(deltaTime)

    self.moveDir = Vec(0,0,0)

    if (self:IsLocallyControlled()) then

        if (Input.IsKeyDown(Key.Left) or Input.IsGamepadButtonDown(Gamepad.Left)) then
            self.moveDir.x = self.moveDir.x + -1.0
        end

        if (Input.IsKeyDown(Key.Right) or Input.IsGamepadButtonDown(Gamepad.Right)) then
            self.moveDir.x = self.moveDir.x + 1.0
        end

        if (Input.IsKeyDown(Key.Up) or Input.IsGamepadButtonDown(Gamepad.Up)) then
            self.moveDir.z = self.moveDir.z + -1.0
        end

        if (Input.IsKeyDown(Key.Down) or Input.IsGamepadButtonDown(Gamepad.Down)) then
            self.moveDir.z = self.moveDir.z + 1.0
        end

        local leftAxisX = Input.GetGamepadAxisValue(Gamepad.AxisLX)
        local leftAxisY = Input.GetGamepadAxisValue(Gamepad.AxisLY)

        -- Only add analog stick input beyond a deadzone limit
        if (math.abs(leftAxisX) > 0.1) then
            self.moveDir.x = self.moveDir.x + leftAxisX
        end
        if (math.abs(leftAxisY) > 0.1) then
            self.moveDir.z = self.moveDir.z - leftAxisY
        end

        -- Ensure length of moveDir is at most 1.0.
        local moveMag = self.moveDir:Magnitude()
        moveMag = math.min(moveMag, 1.0)
        self.moveDir = (self.actionTime <= 0) and self.moveDir:Normalize() or Vec(0,0,0)
        self.moveDir = self.moveDir * moveMag

    end

end

function Bomber:UpdateAction(deltaTime)

    self.actionTime = math.max(self.actionTime - deltaTime, 0)

    if (self:IsLocallyControlled() and self.actionTime <= 0.0) then
        if (Input.IsKeyJustDown(Key.Z) or Input.IsGamepadPressed(Gamepad.B)) then
            -- Plant Bomb
            self:InvokeNetFunc('S_PlantBomb')
        elseif (Input.IsKeyJustDown(Key.X) or Input.IsGamepadPressed(Gamepad.A)) then
            -- Swing Cane
            self:InvokeNetFunc('S_SwingCane')
        end
    end

    -- Handle swing on server
    if (Network.IsAuthority() and self.swingTimer > 0) then
        self.swingTimer = self.swingTimer - deltaTime

        if (self.swingTimer <= 0.0) then

            for k,v in pairs(self.swingOverlaps) do
                local node = v

                if (node:HasTag('Bomber')) then
                    Log.Debug('TODO: Stun bomber')
                elseif (node:HasTag('Bomb')) then
                    -- Note: The bomber mesh is facing -Z so its 'ForwardVector' is actually backwards.
                    local facingDir = -self.mesh:GetForwardVector()
                    node:Launch(facingDir)
                end
            end

            self.swingSphere:EnableOverlaps(false)
        end
    end

    if (self:IsLocallyControlled()) then
        
        if (Input.IsGamepadPressed(Gamepad.Y)) then
            GameState.statsEnabled = not GameState.statsEnabled
            Renderer.EnableStatsOverlay(GameState.statsEnabled)
            Log.Enable(GameState.statsEnabled)
        end
        
        if (Input.IsGamepadPressed(Gamepad.Start)) then
            Engine.GetWorld(1):LoadScene('SC_MainMenu')
        end
    end
end

function Bomber:Move(axes, deltaTime)

    -- Sweep along velocity
    local velocity = self.velocity * axes
    self.velocity = self.velocity - velocity
    local nodePos = self:GetWorldPosition()
    local endPos = nodePos + velocity * deltaTime
    local sweepRes = self:SweepToPosition(endPos)

    if (sweepRes.hitNode) then

        -- Uncomment to debug the hit normal.
        --Renderer.AddDebugLine(sweepRes.hitPosition, sweepRes.hitPosition + sweepRes.hitNormal * 1.0, Vec(0, 1, 0, 1), 3.0)

        -- Update to new position
        nodePos = self:GetWorldPosition()

        -- Cancel out velocity along normal and perform a second sweep
        velocity = velocity - (sweepRes.hitNormal * Vector.Dot(velocity, sweepRes.hitNormal))
        endPos = nodePos + velocity * deltaTime
        sweepRes = self:SweepToPosition(endPos)
    end

    self.velocity = self.velocity + velocity

end

function Bomber:UpdateMotion(deltaTime)

    local isServer = Network.IsServer()

    if (self:IsLocallyControlled() or (isServer and self:IsBot())) then

        -- Gravity
        self.velocity.y = self.velocity.y + deltaTime * Bomber.gravity
        self.velocity.x = 0
        self.velocity.z = 0

        -- Movement Velocity
        local targetMoveVel = self.moveDir * self.moveSpeed
        self.moveVelocity = Math.Approach(self.moveVelocity, targetMoveVel, 25.0, deltaTime)
        self.curMoveSpeed = self.moveVelocity:Magnitude()
        self.velocity = self.velocity + self.moveVelocity

        -- Move in Y direction first
        self:Move(Vec(0, 1, 0), deltaTime)

        -- Move in X/Z plane next (for smoother movement along obstacles)
        self:Move(Vec(1, 0, 1), deltaTime)

    else 
        self:SetWorldPosition(self.netPosition)
    end
end

function Bomber:UpdateAnimation(deltaTime)

    -- Blend between idle and run based on move speed
    local runAlpha = Math.Clamp(self.curMoveSpeed / (self.moveSpeed * 0.5), 0, 1)

    self.mesh:PlayAnimation('Idle', true, 1, 1.0 - runAlpha, 1)
    self.mesh:PlayAnimation('Run', true, 1, runAlpha, 2)

end


function Bomber:UpdateOrientation(deltaTime)

    if (self:IsLocallyControlled()) then
        if (self.curMoveSpeed > 0.01) then
            local moveDir = self.moveVelocity:Normalize()
            local facingDir = -moveDir
            local moveOrientation = Math.VectorToRotation(facingDir)
            self.mesh:SetWorldRotation(moveOrientation)
        end
    else
        self.mesh:SetWorldRotation(Vec(0, self.netYaw, 0))
    end

end

function Bomber:UpdateCell(deltaTime)

    local match = GameState:GetMatch()
    local worldPos = self:GetWorldPosition()
    self.cellX, self.cellZ = match:GetCell(worldPos)

end

function Bomber:UpdateCamera(deltaTime)

    if (not self:IsLocallyControlled()) then
        return
    end

    local axisRX = Input.GetGamepadAxisValue(Gamepad.AxisRX)
    local axisRY = Input.GetGamepadAxisValue(Gamepad.AxisRY)

    if (math.abs(axisRY) > 0.2) then
        -- Zoom in/out
        local maxCamDist = 6.0
        local minCamDist = 2.0
        local zoomSpeed = 6.0

        local camDist = self.camera:GetPosition():Magnitude()
        camDist = Math.Clamp(camDist + zoomSpeed * -axisRY * deltaTime, minCamDist, maxCamDist)
        local newPos = self.camera:GetPosition():Normalize() * camDist
        self.camera:SetPosition(newPos)
    end

end

function Bomber:UpdateNetwork(deltaTime)

    if (self:IsLocallyControlled()) then
        self:InvokeNetFunc('S_SyncTransform', self:GetWorldPosition(), self.mesh:GetWorldRotation().y, self.curMoveSpeed)
    end
    
end

function Bomber:Kill()

    Log.Debug('Bomber kill! ' .. self:GetName())

end

function Bomber:AddPowerup(powerupType)

    if (not Network.IsAuthority()) then
        return
    end

    Log.Debug('Get Powerup: ' .. powerupType)

    if (powerupType == PowerupType.BombCount) then
        self.bombPowerups = Math.Clamp(self.bombPowerups + 1, 0, Bomber.kMaxPowerupStacks)
        self.bombCount = 1 + self.bombPowerups
    elseif (powerupType == PowerupType.BombRange) then
        self.rangePowerups = Math.Clamp(self.rangePowerups + 1, 0, Bomber.kMaxPowerupStacks)
        self.bombRange = 1 + self.rangePowerups
    elseif (powerupType == PowerupType.MoveSpeed) then
        self.speedPowerups = Math.Clamp(self.speedPowerups + 1, 0, Bomber.kMaxPowerupStacks)
        self.moveSpeed = Bomber.kDefaultMoveSpeed + 0.5 * self.speedPowerups
    end

end

function Bomber:DecrementPlacedBomb()

    self.placedBombs = math.max(self.placedBombs - 1, 0)

end

function Bomber:S_PlantBomb()

    Log.Debug('PlantBomb')

    if (self.actionTime <= 0 and
        self.placedBombs < self.bombCount) then

        local match = GameState:GetMatch()
        local x,z = match:GetCell(self:GetWorldPosition())

        -- Make sure the grid space is empty
        if (match:GetGridObject(x,z) == nil) then
            Log.Debug('Instantiate bomb!')
            local bomb = self.bombScene:Instantiate()
            match.field:AddChild(bomb)
            bomb:SetWorldPosition(Vec(x, bomb:GetRadius() + 0.04, z))
            bomb:SetRange(self.bombRange)
            bomb:SetBomber(self)
            self.placedBombs = self.placedBombs + 1
        end
    end

end

function Bomber:S_SwingCane()

    if (self.actionTime <= 0.0) then
        self:InvokeNetFunc('M_SwingCane')
        self.swingTimer = 0.15
        self.swingSphere:EnableOverlaps(true)
    end

end

function Bomber:S_SyncTransform(position, yaw, speed)

    -- Client has full control over position / yaw. (Server is trusting the client)
    -- This means cheating is easy, but the positive side is that the client's movement will feel responsive.
    self.netPosition = position 
    self.netYaw = yaw
    self.curMoveSpeed = speed
end

function Bomber:C_ForceWorldPosition(position)

    self:SetWorldPosition(position)
    self.netPosition = position

end

function Bomber:M_SwingCane()

    self.mesh:PlayAnimation('Swing')
    self.actionTime = 0.3
end
