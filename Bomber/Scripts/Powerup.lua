Powerup = 
{
    powerupType = PowerupType.Count,
}

function Powerup:Start()

    self.mesh = self:FindChild('Mesh', true)

end

function Powerup:GatherReplicatedData()

    return
    { 
        { name = 'powerupType', type = DatumType.Byte, onRep = 'OnRep_powerupType' },
    }

end


function Powerup:Tick(deltaTime)

    self.mesh:AddRotation(Vec(0, 150.0, 0) * deltaTime)

end

function Powerup:BeginOverlap(this, other)

    if (Network.IsAuthority() and 
        this == self and 
        not self:IsPendingDestroy() and 
        other:HasTag('Bomber')) then

        other:AddPowerup(self.powerupType)
        self:SetPendingDestroy(true)
    end

end

function Powerup:SetType(powerupType)
    self.powerupType = powerupType
    self:OnRep_powerupType()
end

function Powerup:GetType()
    return self.powerupType
end

function Powerup:OnRep_powerupType()

    local mesh = nil

    Log.Debug('PowerupType = ' .. self.powerupType)

    if (self.powerupType == PowerupType.BombCount) then 
        mesh = LoadAsset('SM_PowerupBomb')
    elseif (self.powerupType == PowerupType.BombRange) then
        mesh = LoadAsset('SM_PowerupFire')
    elseif (self.powerupType == PowerupType.MoveSpeed) then
        mesh = LoadAsset('SM_PowerupSpeed')
    end

    self.mesh:SetStaticMesh(mesh)

end
