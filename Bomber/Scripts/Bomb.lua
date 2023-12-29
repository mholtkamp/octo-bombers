Bomb = 
{
    kExplodeDelay = 4.0,
    kLaunchSpeed = 8.0,
    kDragSpeed = 8.0,
}

function Bomb:GatherProperties()
    return 
    {
        { name = 'explodeParticle', type = DatumType.Asset },
    }
end

function Bomb:GatherReplicatedData()

    return 
    {
        { name = 'range', type = DatumType.Byte },
    }

end

function Bomb:GatherNetFuncs()
    return
    {
        { name = 'M_Explode', type = NetFuncType.Multicast, reliable = true},
    }
end

function Bomb:Create()

    self.time = Bomb.kExplodeDelay
    self.range = 1
    self.velocity = Vec()
    self.exploded = false
    self.owner = nil
    self.numOverlappedBombers = 0
    self.collisionEnabled = false

end

function Bomb:Start()

    self.mesh = self:FindChild('Mesh', true)
    self.material = self.mesh:InstantiateMaterial()

    local match = MatchState.Get()
    local x,z = match:GetCell(self:GetWorldPosition())
    self.objectType = ObjectType.Bomb
    self.x = x
    self.z = z

    if (match:GetGridObject(x,z) ~= nil) then
        Log.Error('Bomb is overlapping grid object??')
    end

    match:SetGridObject(x, z, self)

end


function Bomb:Stop()

    Log.Debug('Bomb stop!!')
    local match = MatchState.Get()

    if (match:GetGridObject(self.x, self.z) ~= self) then
        Log.Error('Bomb is not in expected grid cell?')
    end

    match:SetGridObject(self.x, self.z, nil)

    if (self.bomber) then
        self.bomber:DecrementPlacedBomb()
    end

end

function Bomb:BeginOverlap(this, other)

    if (not self.collisionEnabled and 
        this == self and
        other:HasTag('Bomber')) then

        self.numOverlappedBombers = self.numOverlappedBombers + 1
    end

end

function Bomb:EndOverlap(this, other)

    if (not self.collisionEnabled and
        this == self and
        other:HasTag('Bomber')) then

        self.numOverlappedBombers = self.numOverlappedBombers - 1
    end
end

function Bomb:SetRange(range)

    if (Network.IsAuthority()) then
        self.range = range
    end

end

function Bomb:Tick(deltaTime)

    self.time = self.time - deltaTime

    self:UpdateVisuals(deltaTime)
    self:UpdateExplosion(deltaTime)
    self:UpdateCollision(deltaTime)
    self:UpdateCell(deltaTime)
    self:UpdateMovement(deltaTime)

end

function Bomb:UpdateVisuals(deltaTime)

    -- Pulse mesh and flash material
    local bombScale = 1.1 + 0.1 * math.sin(self.time * 5)
    local bombRed = 1.0 + 0.4 * math.sin(self.time * 7)
    self.mesh:SetScale(Vec(bombScale, bombScale, bombScale))
    self.material:SetColor(Vec(bombRed, 1, 1, 1))

end

function Bomb:UpdateExplosion(deltaTime)

    if (self.time <= 0.0 and Network.IsAuthority()) then
        self:Explode()
    end

end

function Bomb:UpdateCollision(deltaTime)

    if (not self.collisionEnabled and 
        self.numOverlappedBombers == 0 and 
        Bomb.kExplodeDelay - self.time > 0.3) then
        self.collisionEnabled = true 
        self:EnableCollision(true)
    end

end

function Bomb:UpdateCell(deltaTime)

    local match = MatchState.Get()
    local curX, curZ = match:GetCell(self:GetWorldPosition())

    if (self.x ~= curX or self.z ~= curZ) then
        -- Cell has changed, so update our saved X/Z and match grid
        if (match:GetGridObject(self.x, self.z) == self) then
            match:SetGridObject(self.x, self.z, nil)
        end

        self.x = curX
        self.z = curZ

        if (match:GetGridObject(self.x, self.z) == nil) then
            match:SetGridObject(self.x, self.z, self)
        end
    end

    if (self.x == -1 or self.z == -1) then
        self:SetPendingDestroy(true)
    end

end

function Bomb:UpdateMovement(deltaTime)

    -- Handle movement
    if (Network.IsAuthority()) then 
        local speed = self.velocity:Magnitude()
        if (speed > 0.0001) then
            local startPos = self:GetWorldPosition()
            local endPos = startPos + self.velocity * deltaTime
            local sweepRes = self:SweepToPosition(endPos, ~(BomberCollision.Trigger))

            if (sweepRes.hitNode) then
                self.velocity = -self.velocity
            end

            -- Dampen velocity / apply friction
            local speed = self.velocity:Length()
            self.velocity = self.velocity / speed 
            speed = math.max(speed - Bomb.kDragSpeed * deltaTime, 0)
            self.velocity = self.velocity * speed
        end

        if (speed < 0.3 and self.x ~= -1 and self.z ~= -1) then
            -- Gravitate toward cell position
            local curPos = self:GetWorldPosition()
            local targetPos = Vec(self.x, curPos.y, self.z)
            local newPos = Vector.Damp(curPos, targetPos, 0.05, deltaTime)
            self:SetWorldPosition(newPos)
        end
    end

end

function Bomb:Explode()
    if (Network.IsAuthority()) then
        self:InvokeNetFunc('M_Explode')
        self:SetPendingDestroy(true)
    end
end

function Bomb:SetBomber(bomber)
    self.bomber = bomber 
end

function Bomb:Launch(dir)
    if (Network.IsAuthority()) then
        local absX = math.abs(dir.x)
        local absZ = math.abs(dir.z)

        -- Determine the closest axis-aligned direction
        local axisDir = Vec(0,0,0)
        if (absX > absZ) then
            if (dir.x >= 0) then
                axisDir = Vec(1, 0, 0)
            else
                axisDir = Vec(-1, 0, 0)
            end
        else
            if (dir.z >= 0) then
                axisDir = Vec(0, 0, 1)
            else
                axisDir = Vec(0, 0, -1)
            end
        end

        self.velocity = axisDir * Bomb.kLaunchSpeed

    end
end

function Bomb:SpawnExplodeParticle(x, z)

    world:SpawnParticle(self.explodeParticle, Vec(x, 0, z))

end

function Bomb:ExplodeCell(x, z)

    local match = MatchState.Get()
    local authority = Network.IsAuthority()
    local dimX = match.gridSizeX 
    local dimZ = match.gridSizeZ

    if (x < 1 or x > dimX or 
        z < 1 or z > dimZ) then
        return false 
    end

    local object = match:GetGridObject(x, z)

    if (authority and object) then

        if (object:HasTag('Box')) then
            if (not object:IsPendingDestroy()) then
                object:DropPowerup()
                object:SetPendingDestroy(true)
                self:SpawnExplodeParticle(x, z)
            end
            return false
        elseif (object.objectType == ObjectType.Bomb) then 
            if (not object.exploded) then
                object:Explode()
            end
        else
            -- Discontinue explosion (blocked)
            return false
        end
    end

    -- Normal cell, spawn explode particle 
    self:SpawnExplodeParticle(x, z)

    -- Check if we need to kill any bombers
    if (authority) then 
        for i = 1, #match.bombers do 
            local bomber = match.bombers[i]
            if (bomber.cellX == x and
                bomber.cellZ == z) then
                
                bomber:Kill()
            end
        end
    end

    return true

end

function Bomb:M_Explode()

    local match = MatchState.Get()
    local authority = Network.IsAuthority()
    local x,z = match:GetCell(self:GetWorldPosition())
    self.exploded = true

    -- Do not explode if cell position is invalid (knocked off the map)
    if (x >= 1 and z >= 1) then

        -- Hit +X
        for i = 1, self.range do 
            if (not self:ExplodeCell(x + i ,z)) then
                break
            end
        end

        -- Hit -X
        for i = 1, self.range do 
            if (not self:ExplodeCell(x - i ,z)) then
                break
            end
        end

        -- Hit +Z
        for i = 1, self.range do 
            if (not self:ExplodeCell(x, z + i)) then
                break
            end
        end

        -- Hit -Z
        for i = 1, self.range do 
            if (not self:ExplodeCell(x, z - i)) then
                break
            end
        end

        -- Hit exact X,Z where bomb was positioned
        self:ExplodeCell(x, z)
    end

end