Bomber = 
{
    gravity = -9.8,
}

function Bomber:Create()

    self.moveDir = Vec(0,0,0)
    self.moveVelocity = Vec(0,0,0)
    self.velocity = Vec(0,0,0)
    self.moveSpeed = 3.5
    self.cellX = 0
    self.cellZ = 0
    self.actionTime = 0.0
    self.bomberId = 1
    self.netYaw = 0.0
    self.netPosition = Vec()
    self.curMoveSpeed = 0
    self.swingOverlaps = {}
    self.swingTimer = 0.0
end

function Bomber:Start()

    self.mesh = self:FindChild('Mesh', true)
    self.camera = self:FindChild('Camera', true)
    self.swingSphere = self:FindChild('SwingSphere', true)
    
    if (self.camera) then
        world:SetActiveCamera(self.camera)
    end

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
        { name = 'netPosition', type = DatumType.Vector },
        { name = 'curMoveSpeed', type = DatumType.Float }
    }

end

function Bomber:GatherNetFuncs()
    
    return 
    {
        { name = 'S_PlantBomb', type = NetFuncType.Server, reliable = true},
        { name = 'S_SwingCane', type = NetFuncType.Server, reliable = true},
        { name = 'S_SyncTransform', type = NetFuncType.Server, reliable = false},

        { name = 'M_SwingCane', type = NetFuncType.Client, reliable = false},
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

function Bomber:Tick(deltaTime)

    self:UpdateMovement(deltaTime)
    self:UpdateAction(deltaTime)
    self:UpdateMotion(deltaTime)
    self:UpdateAnimation(deltaTime)
    self:UpdateOrientation(deltaTime)
    self:UpdateCell(deltaTime)
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

        self.moveDir = (self.actionTime <= 0) and self.moveDir:Normalize() or Vec(0,0,0)

    end

end

function Bomber:UpdateAction(deltaTime)

    self.actionTime = math.max(self.actionTime - deltaTime, 0)

    if (self:IsLocallyControlled() and self.actionTime <= 0.0) then
        if (Input.IsKeyJustDown(Key.Z) or Input.IsGamepadButtonDown(Gamepad.B)) then
            -- Plant Bomb
            self:InvokeNetFunc('S_PlantBomb')
        elseif (Input.IsKeyJustDown(Key.X) or Input.IsGamepadButtonDown(Gamepad.A)) then
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

    if (self:IsLocallyControlled()) then

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

    local match = MatchState.Get()
    local worldPos = self:GetWorldPosition()
    self.cellX, self.cellZ = match:GetCell(worldPos)

end

function Bomber:UpdateNetwork(deltaTime)

    if (self:IsLocallyControlled()) then

        self:InvokeNetFunc('S_SyncTransform', self:GetWorldPosition(), self.mesh:GetWorldRotation().y, self.curMoveSpeed)

    end
    
end

function Bomber:Kill()

    Log.Debug('Bomber kill! ' .. self:GetName())

end


function Bomber:S_PlantBomb()

    Log.Debug('PlantBomb')

    if (self.actionTime <= 0) then
        local match = MatchState.Get()
        local x,z = match:GetCell(self:GetWorldPosition())

        -- Make sure the grid space is empty
        if (match:GetGridObject(x,z) == nil) then
            Log.Debug('Instantiate bomb!')
            local bomb = self.bombScene:Instantiate()
            match.field:AddChild(bomb)
            bomb:SetWorldPosition(Vec(x, bomb:GetRadius() + 0.04, z))
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

function Bomber:M_SwingCane()

    self.mesh:PlayAnimation('Swing')
    self.actionTime = 0.3
end
