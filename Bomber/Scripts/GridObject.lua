Script.Require("MatchState")

GridObject =
{
    objectType = ObjectType.None,
    x = -1,
    z = -1,
}

Script.Extend(GridObject, StaticMesh3D)

function GridObject:Create()


end

function GridObject:GatherReplicatedData()

    return
    {
        { name = "objectType", type = DatumType.Byte },
        { name = "x", type = DatumType.Byte },
        { name = "z", type = DatumType.Byte },
    }

end

function GridObject:Start()

    local match = GameState:GetMatch()
    match:SetGridObject(self.x, self.z, self)
    self:SetWorldPosition(Vec(self.x, 0, self.z))

end


function GridObject:Stop()

    local match = GameState:GetMatch()
    local gridObj = match:GetGridObject(self.x, self.z)

    if (gridObj == self) then
        match:SetGridObject(self.x, self.z, nil)
    end

end