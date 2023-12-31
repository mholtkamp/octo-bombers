MenuOption = 
{
    activateFunc = nil,
}


function MenuOption:Tick(deltaTime)

    if (self:ContainsMouse() and Input.IsPointerDown(1)) then
        self:Activate()
    end

end

function MenuOption:Activate()

    if (self.activateFunc) then
        self.activateFunc()
    end

end

function MenuOption:SetActivateFunc(func)
    self.activateFunc = func
end