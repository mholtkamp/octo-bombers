Script.Require("Utils.lua")

MatchState = 
{
    kNumBoxVariants = 3,
    current = nil,

    kSpawnRatiosXZ = 
    {
        { x = 0.0, z = 0.0 },
        { x = 1.0, z = 0.0 },
        { x = 0.0, z = 1.0 },
        { x = 1.0, z = 1.0 },

        { x = 0.5, z = 0.0 },
        { x = 1.0, z = 0.5 },
        { x = 0.0, z = 0.5 },
        { x = 0.5, z = 1.0 },
    },
}

MatchState.Get = function()
    return MatchState.current
end


function MatchState:Create()

    self.gridSizeX = 32
    self.gridSizeZ = 32

    self.bombers = {}
    self.numBombers = 4
    self.enableBots = true

    self.objectSpawnChance = 0.8
    self.boxSpawnChance = 0.5
    self.treeRatio = 0.3

end

function MatchState:GatherProperties()

    return 
    {
        { name = "gridSizeX", type = DatumType.Integer },
        { name = "gridSizeZ", type = DatumType.Integer },
        { name = "objectSpawnChance", type = DatumType.Float },
        { name = "boxSpawnChance", type = DatumType.Float },
        { name = "treeRatio", type = DatumType.Float },

        { name = "platformMesh", type = DatumType.Asset },
        { name = "blockScene", type = DatumType.Asset },
        { name = "boxScene", type = DatumType.Asset },
        { name = "treeScene", type = DatumType.Asset },
        { name = "bomberScene", type = DatumType.Asset },
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

    if (MatchState.current ~= nil) then
        Engine.Alert('Two match states created at the same time???')
    end

    MatchState.current = self

    if (Network.IsAuthority()) then
        self:InstantiateBombers()
        self:ResetMatch()
    end

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

    -- Should only be called by server.
    if (not Network.IsAuthority()) then
        return
    end

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

    -- Place Bombers
    local isLocalGame = Network.IsLocal()
    local numSpawnedBombers = 0

    for i = 1, self.numBombers do 
        local bomber = self.bombers[i]
        local spawn = false 

        if (self.enableBots) then
            -- Just reenable all players
            spawn = true
        else
            -- No bots, so only enable bombers with owning hosts
            spawn = (bomber:GetOwningHost() ~= 0)
        end

        if (spawn) then
            numSpawnedBombers = numSpawnedBombers + 1
            local spawnRatioXZ = MatchState.kSpawnRatiosXZ[numSpawnedBombers]
            local spawnPos = Vec(spawnRatioXZ.x * self.gridSizeX, 1.0, spawnRatioXZ.z * self.gridSizeZ)
            spawnPos.x = Math.Clamp(spawnPos.x, 1, self.gridSizeX)
            spawnPos.z = Math.Clamp(spawnPos.z, 1, self.gridSizeZ)

            local xOff = -2 * (spawnRatioXZ.x - 0.5)
            local zOff = -2 * (spawnRatioXZ.z - 0.5)
            spawnPos.x = spawnPos.x + xOff
            spawnPos.z = spawnPos.z + zOff

            bomber:SetWorldPosition(spawnPos)
            bomber:SetAlive(true)

            -- Clear out any grid objects in the nearby cells
            local cellX, cellZ = self:GetCell(spawnPos)
            Log.Debug('cellX = ' .. cellX .. '  cellZ = ' .. cellZ)
            for x = cellX - 1, cellX + 1 do
                for z = cellZ - 1, cellZ + 1 do
                    if (x >= 1 and x <= self.gridSizeX and
                        z >= 1 and z <= self.gridSizeZ) then
                        
                            local gridObj = self:GetGridObject(x, z)
                            if (gridObj) then
                                gridObj:SetPendingDestroy(true)
                                self:SetGridObject(x, z, nil)
                            end
                    end
                end
            end
            
        else
            bomber:SetAlive(false)
        end
    end

end

function MatchState:InstantiateBombers()

    -- Should only be called on the server
    if (not Network.IsAuthority()) then
        return 
    end

    if (#self.bombers ~= 0) then
        Engine.Alert('Bombers array should be empty.')
    end

    -- Spawn the max number of bombers, but disable them 
    for i = 1, self.numBombers do 
        self.bombers[i] = self.bomberScene:Instantiate()
        world:GetRootNode():AddChild(self.bombers[i])
        self.bombers[i].bomberId = i
        self.bombers[i]:SetAlive(false)
    end

end

function MatchState:GenerateGrid()

    self.grid = {}

    for x = 1, self.gridSizeX do
        for z = 1, self.gridSizeZ do

            local gridIdx = x + z * self.gridSizeX

            local roll = Math.RandRange(0.0, 1.0)

            if (roll < self.objectSpawnChance) then

                local objectType = ObjectType.None
                local boxRoll = Math.RandRange(0, 1)
                if (boxRoll < self.boxSpawnChance) then
                    objectType = ObjectType.Box1 + Math.RandRangeInt(0, MatchState.kNumBoxVariants - 1)
                else
                    local useTree = Math.RandRange(0, 1) < self.treeRatio
                    objectType = useTree and ObjectType.Tree or ObjectType.Block
                end

                if (objectType ~= ObjectType.None) then
                    self:SpawnObject(x, z, objectType)
                end
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