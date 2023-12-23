Bomber = 
{
    gravity = -9.8,
}

function Bomber:Create()

    self.moveDir = Vec(0,0,0)
    self.velocity = Vec(0,0,0)
    self.moveSpeed = 5.0

end

function Bomber:Start()

    world:EnableInternalEdgeSmoothing(true)

    self.camera = self:FindChild('Camera', true)
    if (self.camera) then
        world:SetActiveCamera(self.camera)
    end

end

function Bomber:Stop()


end

function Bomber:Tick(deltaTime)

    self:UpdateMovement(deltaTime)
    self:UpdateAction(deltaTime)
    self:UpdateMotion(deltaTime)
    self:UpdateAnimation(deltaTime)

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

function Bomber:UpdateMotion(deltaTime)

    -- Gravity]
    self.velocity.y = self.velocity.y + deltaTime * Bomber.gravity
    self.velocity.x = 0
    self.velocity.z = 0

    -- Movement Velocity
    self.velocity = self.velocity + self.moveDir * self.moveSpeed

    -- Sweep along velocity
    local nodePos = self:GetWorldPosition()
    local endPos = nodePos + self.velocity * deltaTime
    local sweepRes = self:SweepToPosition(endPos)
    local offsetMag = 0.002

    if (sweepRes.hitNode) then
        -- Update to new position
        nodePos = self:GetWorldPosition()

        -- Slightly push node away from hit position to make sure we don't penetrate the hit surface
        nodePos = nodePos + sweepRes.hitNormal * offsetMag
        self:SetWorldPosition(nodePos)

        -- Cancel out velocity along normal and perform a second sweep
        self.velocity = self.velocity - (sweepRes.hitNormal * Vector.Dot(self.velocity, sweepRes.hitNormal))
        endPos = nodePos + self.velocity * deltaTime
        sweepRes = self:SweepToPosition(endPos)
    end

end

function Bomber:UpdateAnimation(deltaTime)

    

end
