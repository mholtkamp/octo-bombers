MainMenu = 
{

}


function MainMenu:Start()

    self.optSolo = self:FindChild('OptSolo', true)
    self.optCreate = self:FindChild('OptCreateNet', true)
    self.optJoin = self:FindChild('OptJoinNet', true)

    local soloFunc = function() GameState:StartSoloMatch() end
    local createFunc = function() GameState:StartNetMatch() end
    local joinFunc = function() GameState:JoinNetMatch() end

    self.optSolo:SetActivateFunc(soloFunc)
    self.optCreate:SetActivateFunc(createFunc)
    self.optJoin:SetActivateFunc(joinFunc)

end

function MainMenu:Tick(deltaTime)

    if (Input.IsGamepadButtonJustDown(Gamepad.Start)) then
        Log.Debug('Starting Solo Match')
        GameState:StartSoloMatch()
    end

    if (Input.IsGamepadPressed(Gamepad.Select)) then
        Engine.Quit()
    end
end
