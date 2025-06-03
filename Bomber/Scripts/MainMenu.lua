MainMenu = 
{

}

function MainMenu:Start()

    self.optSolo = self:FindChild('OptSolo', true)
    self.optCreate = self:FindChild('OptCreateNet', true)
    self.optJoin = self:FindChild('OptJoinNet', true)
    self.buttons = { self.optSolo, self.optCreate, self.optJoin }

    -- OnActivated will pass a self param if needed
    -- You can make a single script that implements an OnActivated function instead of
    -- setting the function externally like we are doing here.
    -- And you can also handle "Activated", "Hovered", "Pressed" signals if you prefer.
    self.optSolo.OnActivated = function() GameState:StartSoloMatch() end
    self.optCreate.OnActivated = function() GameState:StartNetMatch() end
    self.optJoin.OnActivated = function() GameState:JoinNetMatch() end

    for i=1, #self.buttons do 
        self.buttons[i]:ConnectSignal("Hovered", self, function() self.selIndex = i end)
    end

    self.optSolo:SetState(ButtonState.Hovered)
    self.selIndex = 1
end

function MainMenu:Tick(deltaTime)

    -- Button navigation and activation
    if (Input.IsGamepadPressed(Gamepad.Down) or Input.GetGamepadAxis(Gamepad.AxisLY) < -0.5) then
        self.selIndex = self.selIndex + 1
    end

       if (Input.IsGamepadPressed(Gamepad.Up) or Input.GetGamepadAxis(Gamepad.AxisLY) > 0.5) then
        self.selIndex = self.selIndex - 1
    end

    self.selIndex = Math.Clamp(self.selIndex, 1, #self.buttons)

    if (self.buttons[self.selIndex]:GetState() == ButtonState.Normal) then
        self.buttons[self.selIndex]:SetState(ButtonState.Hovered)
    end

    if (Input.IsGamepadPressed(Gamepad.A)) then
        self.buttons[self.selIndex]:Activate()
    end

    -- Start begins a solo match
    if (Input.IsGamepadButtonJustDown(Gamepad.Start)) then
        Log.Debug('Starting Solo Match')
        GameState:StartSoloMatch()
    end

    -- Select quits the game
    if (Input.IsGamepadPressed(Gamepad.Select) or 
            (Input.IsGamepadDown(Gamepad.L1) and Input.IsGamepadDown(Gamepad.R1))) then
        Engine.Quit()
    end

end
