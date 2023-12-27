Script.Require("GridObject")

Box = 
{

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
