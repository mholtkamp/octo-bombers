GameState = 
{
    match = nil,
    searching = false,
    searchTimerHandle = nil,
    statsEnabled = false,
}

function GameState:Init()

    -- Setup network callbacks
    Network.SetConnectCallback(GameState.NetConnect)
    Network.SetAcceptCallback(GameState.NetAccept)
    Network.SetRejectCallback(GameState.NetReject)
    Network.SetDisconnectCallback(GameState.NetDisconnect)
    Network.SetKickCallback(GameState.NetKick)

end

function GameState:Shutdown()

end

function GameState:GetMatch()
    return self.match
end

function GameState:SetMatch(match)

    if (match and self.match) then
        Log.Warning('Overwriting current match!')
    end

    self.match = match
end

function GameState:StartSoloMatch()

    if (not Network.IsLocal()) then
        Network.Disconnect()
    end

    self:EnableSessionSearch(false)

    Engine.GetWorld(1):LoadScene('SC_Match')

    -- Testing second screen functionality
    if (Engine.GetPlatform() == "3DS") then
        Engine.GetWorld(2):LoadScene('SC_Assets')
    end

end

function GameState:StartNetMatch()

    self:EnableSessionSearch(false)

    if (not Network.IsServer()) then
        Network.OpenSession()
    end

    if (Engine.GetPlatform() == "3DS") then
        Engine.GetWorld(2):Clear()
    end

    Engine.GetWorld():LoadScene('SC_Match')

end

function GameState:JoinNetMatch()

    self:EnableSessionSearch(true)

end

function GameState:JoinSession(session)

    self:EnableSessionSearch(true)
end

function GameState:EnableSessionSearch(enable)

    if (enable ~= self.searching) then

        self.searching = enable 

        if (enable) then
            Network.BeginSessionSearch()

            local checkSessions = function()
                local numSessions = Network.GetNumSessions()
                if (numSessions > 0) then
                    -- Just join the first session for now.
                    local session = Network.GetSession(1)

                    Network.Connect(session.ipAddress, session.port)
                    self:EnableSessionSearch(false)
                end
            end

            self.searchTimerHandle = TimerManager.SetTimer(checkSessions, 1.0, true)
        else
            Network.EndSessionSearch()
            TimerManager.ClearTimer(self.searchTimerHandle)
            self.searchTimerHandle = nil
        end

    end


end




-- Network Callbacks
GameState.NetConnect = function(client)

    Log.Debug('Bomber - OnConnect')
    local match = GameState:GetMatch()
    if (match) then
        match:NetConnect(client)
    end

end

GameState.NetAccept = function()
    Log.Debug('Bomber - OnAccept')
end

GameState.NetReject = function(reason)
    Log.Debug('Bomber - OnReject')

end

GameState.NetDisconnect = function(client)
    Log.Debug('Bomber - OnDisconnect')

    local match = GameState:GetMatch()
    if (match) then
        match:NetDisconnect(client)
    end

end

GameState.NetKick = function(reason)
    Log.Debug('Bomber - OnKick')
    Log.Error('TODO: Go back to main menu')
end