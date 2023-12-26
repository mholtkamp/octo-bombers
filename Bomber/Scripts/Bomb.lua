Bomb = 
{
    kExplodeDelay = 4.0,
}

function Bomb:GatherProperties()
    return 
    {
        { name = 'explodeParticle', type = DatumType.Asset },
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
end

function Bomb:Start()

    self.mesh = self:FindChild('Mesh', true)
    self.material = self.mesh:InstantiateMaterial()

end


function Bomb:Stop()


end

function Bomb:Tick(deltaTime)

    self.time = self.time - deltaTime

    -- Pulse mesh and flash material
    local bombScale = 1.0 + 0.5 * math.sin(self.time)
    local bombRed = math.max(bombScale, 1.0)
    self.mesh:SetScale(Vec(bombScale, bombScale, bombScale))
    self.material:SetColor(Vec(bombRed, 1, 1, 1))

    if (self.time <= 0.0) then

        self:InvokeNetFunc('M_Explode')
    end

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

    if (authority and object:HasTag('Box')) then
        object:SetPendingDestroy(true)
        match:SetGridObject(x, z, nil)

        -- TODO: Drop item
        
        return false
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

end

function Bomb:Explode()

    local match = MatchState.Get()
    local authority = Network.IsAuthority()
    local x,z = match:GetCell(self:GetWorldPosition())

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