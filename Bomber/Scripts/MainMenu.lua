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
    self.optSolo.OnActivated = function() GameState:StartSoloMatch() end
    self.optCreate.OnActivated = function() GameState:StartNetMatch() end
    self.optJoin.OnActivated = function() GameState:JoinNetMatch() end

    for i=1, #self.buttons do 
        self.buttons[i].index = i
        self.buttons[i]:ConnectSignal("StateChanged", self, MainMenu.ButtonStateChanged)
    end

    self.selIndex = 1
    Button.SetSelected(self.buttons[1])
end

function MainMenu:ButtonStateChanged(button)

    if (button == Button.GetSelected()) then
        self.selIndex = button.index
        button:GetText():SetColor(Vec(0.2, 0.2, 0.2, 1))
    else
        button:GetText():SetColor(Vec(1,1,1,1))
    end

end

function MainMenu:Tick(deltaTime)

    -- Button navigation and activation
    local selMoved = false
    if (Input.IsGamepadPressed(Gamepad.Down) or Input.IsGamepadPressed(Gamepad.LsDown)) then
        self.selIndex = self.selIndex + 1
        selMoved = true
    end

       if (Input.IsGamepadPressed(Gamepad.Up) or Input.IsGamepadPressed(Gamepad.LsUp)) then
        self.selIndex = self.selIndex - 1
        selMoved = true
    end

    self.selIndex = Math.Clamp(self.selIndex, 1, #self.buttons)

    if (selMoved) then
        Button.SetSelected(self.buttons[self.selIndex])
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
