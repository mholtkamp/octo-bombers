Bomber = 
{
    gravity = -9.8,
}

function Bomber:Create()

    self.moveDir = Vec(0,0,0)
    self.moveVelocity = Vec(0,0,0)
    self.velocity = Vec(0,0,0)
    self.moveSpeed = 3.5

end

function Bomber:Start()

    self.mesh = self:FindChild('Mesh', true)
    self.camera = self:FindChild('Camera', true)
    
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
    }

end

function Bomber:Tick(deltaTime)

    self:UpdateMovement(deltaTime)
    self:UpdateAction(deltaTime)
    self:UpdateMotion(deltaTime)
    self:UpdateAnimation(deltaTime)
    self:UpdateOrientation(deltaTime)

end

function Bomber:UpdateMovement(deltaTime)

    self.moveDir = Vec(0,0,0)

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

    self.moveDir = self.moveDir:Normalize()

end

function Bomber:UpdateAction(deltaTime)


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

end

function Bomber:UpdateAnimation(deltaTime)

    -- Blend between idle and run based on move speed
    local runAlpha = Math.Clamp(self.curMoveSpeed / (self.moveSpeed * 0.5), 0, 1)

    self.mesh:PlayAnimation('Idle', true, 1, 1.0 - runAlpha, 1)
    self.mesh:PlayAnimation('Run', true, 1, runAlpha, 2)

end


function Bomber:UpdateOrientation(deltaTime)

    if (self.curMoveSpeed > 0.01) then
        local moveDir = self.moveVelocity:Normalize()
        local facingDir = -moveDir
        local moveOrientation = Math.VectorToRotation(facingDir)
        self.mesh:SetWorldRotation(moveOrientation)
    end

end