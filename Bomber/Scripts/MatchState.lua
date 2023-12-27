Script.Require("Utils.lua")

MatchState = 
{
    kNumBoxVariants = 3,
    current = nil,
}

MatchState.Get = function()
    return MatchState.current
end


function MatchState:Create()

    self.gridSizeX = 32
    self.gridSizeZ = 32

    self.bombers = {}
    self.numBombers = 4

    self.boxSpawnChance = 0.3
    self.blockSpawnChance = 0.2
    self.treeRatio = 0.3

end

function MatchState:GatherProperties()

    return 
    {
        { name = "gridSizeX", type = DatumType.Integer },
        { name = "gridSizeZ", type = DatumType.Integer },

        { name = "platformMesh", type = DatumType.Asset },
        { name = "blockScene", type = DatumType.Asset },
        { name = "boxScene", type = DatumType.Asset },
        { name = "treeScene", type = DatumType.Asset },
    }
end

function MatchState:GatherNetFuncs()

    return 
    {

    }

end

function MatchState:GatherReplicatedData()

    return 
    {
        { name = 'gridSizeX', type = DatumType.Integer },
        { name = 'gridSizeZ', type = DatumType.Integer },
    }

end


function MatchState:Start()

    self:ResetMatch()

    if (MatchState.current ~= nil) then
        Engine.Alert('Two match states created at the same time???')
    end

    MatchState.current = self

end

function MatchState:Stop()

    MatchState.current = nil

end

function MatchState:GetCell(worldPos)

    local x = Utils.Round(worldPos.x)
    local z = Utils.Round(worldPos.z)

    if (x < 1 or x > self.gridSizeX or
        z < 1 or z > self.gridSizeZ) then
        x = -1
        z = -1
    end

    return x,z
end

function MatchState:ResetMatch()

    if (self.field) then
        self.field:SetPendingDestroy(true)
        self.field = nil
    end

    self.field = world:SpawnNode('Node3D')
    self.field:SetReplicate(true)
    self.field:SetReplicateTransform(true)
    self.field:SetName("Field")
    self.field:SetWorldPosition(Vec(0,0,0))

    -- Ensure gridSize is multiple of 4
    self.gridSizeX = self.gridSizeX - (self.gridSizeX % 4)
    self.gridSizeZ = self.gridSizeZ - (self.gridSizeZ % 4)

    Log.Debug("Match Grid Size = " .. self.gridSizeX .. ' x ' .. self.gridSizeZ)

    local numPlatformsX = self.gridSizeX / 4
    local numPlatformsZ = self.gridSizeZ / 4

    self:GenerateGrid()

    -- Spawn Platforms
    for x = 1, numPlatformsX do 
        for z = 1, numPlatformsZ do
            local platform = self.field:CreateChild('StaticMesh3D')
            local xPos = (x - 1) * 4 + 1
            local zPos = (z - 1) * 4 + 1
            platform:SetWorldPosition(Vec(xPos, 0, zPos))
            platform:EnableTriangleCollision(true)
            platform:EnableCollision(true)
            platform:SetCollisionGroup(BomberCollision.Environment)
            platform:SetCollisionMask(~BomberCollision.Environment)
            platform:SetStaticMesh(self.platformMesh)
            platform:SetReplicate(true)
            platform:SetReplicateTransform(true)
            platform:ForceReplication()
            platform:SetName('Island')
        end
    end

    -- Spawn / Place Bombers

end

function MatchState:GenerateGrid()

    self.grid = {}

    for x = 1, self.gridSizeX do
        for z = 1, self.gridSizeZ do

            local gridIdx = x + z * self.gridSizeX

            local roll = Math.RandRange(0.0, 1.0)
            local objectType = ObjectType.None

            if (roll < self.boxSpawnChance) then
                objectType = ObjectType.Box1 + Math.RandRangeInt(0, MatchState.kNumBoxVariants - 1)
            elseif (roll < self.boxSpawnChance + self.blockSpawnChance) then
                local useTree = Math.RandRange(0, 1) < self.treeRatio
                objectType = useTree and ObjectType.Tree or ObjectType.Block
            end

            if (objectType ~= ObjectType.None) then
                self:SpawnObject(x, z, objectType)
            end

        end
    end

end

function MatchState:GetGridObject(x, z)

    return self.grid[x + z * self.gridSizeX]

end

function MatchState:SetGridObject(x, z, object)

    self.grid[x + z * self.gridSizeX] = object

end

function MatchState:SpawnObject(x, z, objectType)

    local object = nil

    if (objectType >= ObjectType.Box1 and objectType <= ObjectType.Box3) then
        object = self.boxScene:Instantiate()
    elseif (objectType == ObjectType.Tree) then
        object = self.treeScene:Instantiate()
    elseif (objectType == ObjectType.Block) then
        object = self.blockScene:Instantiate()
    end


    if (object) then
        self.field:AddChild(object)
        object.objectType = objectType
        object.x = x
        object.z = z 
        object:SetWorldPosition(Vec(x, 0, z))
        object:ForceReplication()

        self:SetGridObject(x, z, object)
    end
end