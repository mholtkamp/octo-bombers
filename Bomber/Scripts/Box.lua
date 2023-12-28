Script.Require("GridObject")

Box = 
{
    kDropChance = 0.3,

    powerupScene = LoadAsset('SC_Powerup')
}

Script.Extend(Box, GridObject)

function Box:Start()

    GridObject.Start(self)

    if (self.objectType == ObjectType.Box2) then
        self:SetMaterialOverride('M_GiftBox2')
    elseif (self.objectType == ObjectType.Box3) then
        self:SetMaterialOverride('M_GiftBox3')
    end

end

function Box:DropPowerup()

    -- This function should only be called on server
    if (not Network.IsAuthority()) then
        return
    end

    local roll = Math.RandRange(0, 1)

    if (roll < 0.3) then
        Log.Error('Dropping powerup!')
        local match = MatchState.Get()
        local powerupType = Math.RandRangeInt(1, PowerupType.Count)

        local powerup = Box.powerupScene:Instantiate()
        powerup:SetWorldPosition(Vec(self.x, powerup:GetRadius() + 0.04, self.z))
        powerup:Start()
        powerup:SetType(powerupType)
        match.field:AddChild(powerup)
    end

end

