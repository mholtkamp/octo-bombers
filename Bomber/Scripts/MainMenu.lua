MainMenu = 
{

}

function MainMenu:Start()

    self.optSolo = self:FindChild('OptSolo', true)
    self.optCreate = self:FindChild('OptCreateNet', true)
    self.optJoin = self:FindChild('OptJoinNet', true)

    -- OnActivated will pass a self param if needed
    -- You can make a single script that implements an OnActivated function instead of
    -- setting the function externally like we are doing here.
    -- And you can also handle "Activated", "Hovered", "Pressed" signals if you prefer.
    self.optSolo.OnActivated = function() GameState:StartSoloMatch() end
    self.optCreate.OnActivated = function() GameState:StartNetMatch() end
    self.optJoin.OnActivated = function() GameState:JoinNetMatch() end

end

function MainMenu:Tick(deltaTime)

    if (Input.IsGamepadButtonJustDown(Gamepad.Start)) then
        Log.Debug('Starting Solo Match')
        GameState:StartSoloMatch()
    end

    if (Input.IsGamepadPressed(Gamepad.Select) or 
            (Input.IsGamepadDown(Gamepad.L1) and Input.IsGamepadDown(Gamepad.R1))) then
        Engine.Quit()
    end
end
