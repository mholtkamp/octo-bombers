Script.Require("GridObject")

Tree = 
{

}

Script.Extend(Tree, GridObject)

function Tree:Start()

    GridObject.Start(self)

    self:SetRotation(Vec(0, Math.RandRange(0.0, 360.0), 0))

end
