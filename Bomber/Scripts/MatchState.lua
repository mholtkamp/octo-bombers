Script.Require("Utils.lua")

MatchState = 
{

}

function MatchState:Create()

    self.gridSizeX = 32
    self.gridSizeZ = 32

end

function MatchState:GatherProperties()

    return 
    {
        { name = "gridSizeX", type = DatumType.Integer },
        { name = "gridSizeZ", type = DatumType.Integer },

        { name = "platformMesh", type = DatumType.Asset },
        { name = "blockMesh", type = DatumType.Asset },
        { name = "treeScene", type = DatumType.Asset },
        { name = "boxes", type = DatumType.Asset, array = true},
    }
end

function MatchState:Start()

    self:ResetMatch()

end

function MatchState:GetCell(worldPos)

    local x = Utils.Round(worldPos.x)
    local z = Utils.Round(worldPos.z)

    x = Math.Clamp(x, 0, self.gridSizeX)
    z = Math.Clamp(z, 0, self.gridSizeZ)

    return x,z
end

function MatchState:ResetMatch()

    if (self.field) then
        self.field:SetPendingDestroy(true)
        self.field = nil
    end

    self.field = world:SpawnNode('Node3D')
    self.field:SetWorldPosition(Vec(0,0,0))

    -- Ensure gridSize is multiple of 4
    self.gridSizeX = self.gridSizeX - (self.gridSizeX % 4)
    self.gridSizeZ = self.gridSizeZ - (self.gridSizeZ % 4)

    Log.Debug("Match Grid Size = " .. self.gridSizeX .. ' x ' .. self.gridSizeZ)

    local numPlatformsX = self.gridSizeX / 4
    local numPlatformsZ = self.gridSizeZ / 4

    -- Spawn Platforms
    for x = 1, numPlatformsX do 
        for z = 1, numPlatformsZ do
            local platform = self.field:CreateChild('StaticMesh3D')
            local xPos = (x - 1) * 4
            local zPos = (z - 1) * 4
            platform:SetWorldPosition(Vec(xPos, 0, zPos))
            platform:EnableTriangleCollision(true)
            platform:EnableCollision(true)
            platform:SetCollisionGroup(BomberCollision.Environment)
            platform:SetCollisionMask(~BomberCollision.Environment)
            platform:SetStaticMesh(self.platformMesh)
        end
    end

    -- Spawn Trees


    -- Spawn Blocks


    -- Spawn / Place Bombers

end