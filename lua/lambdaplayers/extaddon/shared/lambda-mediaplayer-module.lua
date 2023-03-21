local random = math.random
local rand = math.Rand
local IsValid = IsValid
local CurTime = CurTime


local allowrequesting = CreateLambdaConvar( "lambdaplayers_media_allowrequesting", 1, true, false, false, "If Lambdas are allowed to request videos on Media Players", 0, 1, { type = "Bool", name = "Allow Media Request", category = "Lambda Server Settings" } )

local function Initialize( self )

    self.l_mediaplayer = nil -- The Media Player we are currently watching
    self.l_desiredwatchposition = nil -- The position away from the media player we want to watch from
    self.l_watchendtime = 0
    self.l_randomwatchline = 0

    -- Returns a random URL
    function self:GetRandomMedia()
        for url, info in RandomPairs( LambdaPlayerMediaData ) do
            return url
        end
    end

    -- Requests a URL on a specified media player to play
    function self:RequestMedia( mediaplayer, url )
        self:Thread( function()

            self:DebugPrint( "Requesting Media.." )

            local shouldend = false
            local function CreateMedia( url )
                local media = MediaPlayer.GetMediaForUrl( url )

                local title
                local duration
                local isrequesting = true
                media:GetMetadata( function( result )
                    if !result then isrequesting = false shouldend = true return end
                    title = result.title
                    duration = result.duration
                    isrequesting = false
                end )

                media._metadata = {
                    title = title,
                    duration = duration
                }
                media._OwnerName = self:GetLambdaName()
                media._OwnerSteamID = self:SteamID()
                media:StartTime( RealTime() )

                while isrequesting do coroutine.yield() end

                return media
            end
        
            local media = CreateMedia( url )

            if shouldend then self:DebugPrint( "Failed to get media from " .. url ) return end
            self:DebugPrint( "Successfully received media from " .. url .. "\nTitle: " .. media._metadata.title .. "\nDuration: " .. media._metadata.duration )

            local mp = mediaplayer:GetMediaPlayer()
        
            mp:SetPlayerState( MP_STATE_PLAYING )
        
            mp:SetMedia( media )
            mp:SendMedia( media )
            mp:QueueUpdated()
        
            mp:BroadcastUpdate()
        end, "mediarequesting" )
    
    end

    function self:WatchingMediaPlayer()
        if !IsValid( self.l_mediaplayer ) then self:SetState( "Idle" ) self:PreventDefaultComs( false ) return end
        self:PreventDefaultComs( true )

        self:LookTo( self.l_mediaplayer, 3 )

        local pos = self.l_mediaplayer:GetPos() + self.l_mediaplayer:GetForward() * self.l_desiredwatchposition[ 1 ] + self.l_mediaplayer:GetRight() * self.l_desiredwatchposition[ 2 ]

        if self:GetRangeSquaredTo( pos ) > ( 30 * 30 ) then
            self:MoveToPos( pos )
        end

        if allowrequesting:GetBool() and math.random( 1000 ) == 1 and !self.l_mediaplayer:GetMediaPlayer():IsPlaying() then
            local rndurl = self:GetRandomMedia()
            if rndurl then self:RequestMedia( self.l_mediaplayer, rndurl ) end
        end

        if CurTime() > self.l_randomwatchline then

            if random( 1, 100 ) <= self:GetVoiceChance() and !self:IsSpeaking() then
                self:PlaySoundFile( self:GetVoiceLine( "mediawatch" ), true )
            elseif random( 1, 100 ) <= self:GetTextChance() and !self:IsSpeaking() and self:CanType() and !self:InCombat() then
                self:TypeMessage( self:GetTextLine( "mediawatch" ) )
            end

            self.l_randomwatchline = CurTime() + rand( 10, 30 )
        end

        if CurTime() > self.l_watchendtime then
            self:SetState( "Idle" )
            self:PreventDefaultComs( false )
        end

    end

end


local function Mediawatch( self )
    local nearby = self:FindInSphere( nil, 2000, function( ent ) return ent:GetClass() == "mediaplayer_tv" end )
    local mediaplayer = nearby[ random( #nearby ) ]

    if !IsValid( mediaplayer ) then return end

    self.l_mediaplayer = mediaplayer
    self.l_desiredwatchposition = { random( 100, 200 ), random( -200, 200 )}
    self.l_watchendtime = CurTime() + rand( 5, 180 )
    self.l_randomwatchline = CurTime() + rand( 10, 30 )
    self:SetState( "WatchingMediaPlayer" )
end

LambdaCreatePersonalityType( "MediaWatch", Mediawatch )
LambdaRegisterVoiceType( "mediawatch", "randomengine", "These a voice lines that are played while a Lambda is watching a media player" )

hook.Add( "LambdaOnInitialize", "lambdamediawatch_init", Initialize )





if SERVER then 
    util.AddNetworkString( "lambdaplayers_media_requestmediadata" )

    local function CreateMedia( url )
        local media = MediaPlayer.GetMediaForUrl( url )

        local shouldend = false
        local title
        local duration
        local isrequesting = true
        media:GetMetadata( function( result )
            if !result then isrequesting = false shouldend = true return end
            title = result.title
            duration = result.duration
            isrequesting = false
        end )

        while isrequesting do coroutine.yield() end

        if shouldend then return end

        return title, duration
    end

    net.Receive( "lambdaplayers_media_requestmediadata", function( len, ply )
        local url = net.ReadString()

        LambdaCreateThread( function()
            local title, duration = CreateMedia( url )
            
            net.Start( "lambdaplayers_media_requestmediadata" )
            net.WriteString( title or "" )
            net.WriteUInt( duration or 0, 32 )
            net.Send( ply ) 
        
        end )

    end )

    if !file.Exists( "lambdaplayers/mediadata.json", "DATA" ) then 
        LAMBDAFS:WriteFile( "lambdaplayers/mediadata.json", LAMBDAFS:ReadFile( "materials/lambdaplayers/data/defaultmediadata.vmt", "json", "GAME" ), "json" )
    end

    -- Load Media Data
    LambdaPlayerMediaData = LambdaPlayerMediaData or {}

    local function UpdateMediaData()
        local data = LAMBDAFS:ReadFile( "lambdaplayers/mediadata.json", "json" )
        if !data then return end
        LambdaPlayerMediaData = data
    end

    UpdateMediaData()
    hook.Add( "LambdaOnDataUpdate", "lambdamediawatch_updatedata", UpdateMediaData )

end


if CLIENT then

    local function OpenMediaPanel( ply )
        if !ply:IsSuperAdmin() then notification.AddLegacy( "You must be a Super Admin in order to use this!", 1, 4) surface.PlaySound( "buttons/button10.wav" ) return end
        
        local frame = LAMBDAPANELS:CreateFrame( "Media Panel", 600, 300 )

        LAMBDAPANELS:CreateLabel( "Enter a youtube URL below to register it. Right click a URL row to remove it", frame, TOP )

        local urllist = vgui.Create( "DListView", frame )
        urllist:Dock( FILL )
        urllist:AddColumn( "URL", 1 )
        urllist:AddColumn( "Video Title", 2 )
        urllist:AddColumn( "Video Duration", 3 )

        function urllist:OnRowRightClick( id, line )
            self:RemoveLine( id )
            surface.PlaySound( "buttons/button14.wav" )
        end

        local urlinput = LAMBDAPANELS:CreateTextEntry( frame, BOTTOM, "Enter a youtube URL here. Example: https://www.youtube.com/watch?v=89dGC8de0CA")
        urlinput:SetSize( 10, 20 )
        urlinput:Dock( BOTTOM )

        LAMBDAPANELS:CreateButton( frame, BOTTOM, "Reset to Default", function()
            urllist:Clear()
            local tbl = LAMBDAFS:ReadFile( "materials/lambdaplayers/data/defaultmediadata.vmt", "json", "GAME" )
            for url, info in pairs( tbl ) do 
                urllist:AddLine( url, info.title, info.duration )
            end
        end )

        local working = false

        function urlinput:OnEnter( value )
            if working then chat.AddText( "Please wait for the current URL to validate!" ) return end
            local line = urllist:AddLine( value, "Validating..", "Validating.." )
            surface.PlaySound( "buttons/button14.wav" )
            chat.AddText( "Please wait for the URL to be validated.." )

            self:SetText( "" )

            working = true

            net.Receive( "lambdaplayers_media_requestmediadata", function()
                working = false

                if !IsValid( frame ) then return end

                local title = net.ReadString()
                local duration = net.ReadUInt( 32 )
                if title == "" then chat.AddText( value .. " is not a valid URL!" ) urllist:RemoveLine( line:GetID() ) surface.PlaySound( "buttons/button10.wav" ) return end

                chat.AddText( value .. " validated successfully" )
                surface.PlaySound( "buttons/button5.wav" )

                line:SetColumnText( 2, title )
                line:SetColumnText( 3, tostring( duration ) )
            end )

            net.Start( "lambdaplayers_media_requestmediadata" )
            net.WriteString( value )
            net.SendToServer()

        end

        function frame:OnClose()
            local datatable = {}

            for k, v in pairs( urllist:GetLines() ) do
                datatable[ v:GetColumnText( 1 ) ] = {} -- Url table
                datatable[ v:GetColumnText( 1 ) ].title = v:GetColumnText( 2 ) -- Title
                datatable[ v:GetColumnText( 1 ) ].duration = v:GetColumnText( 3 ) -- Duration
            end

            LAMBDAPANELS:WriteServerFile( "lambdaplayers/mediadata.json", datatable, "json" ) 

            chat.AddText( "Remember to Update Lambda Data after any changes!" )
        end

        LAMBDAPANELS:RequestDataFromServer( "lambdaplayers/mediadata.json", "json", function( data )
            if !data then return end 

            for url, info in pairs( data ) do 
                urllist:AddLine( url, info.title, info.duration )
            end
        end )

    end

    RegisterLambdaPanel( "Media", "Opens a panel that allows you to register youtube URLs for Lambdas to use when they watch a media player. YOU MUST UPDATE LAMBDA DATA AFTER ANY CHANGES! You must be a super admin to use this panel!", OpenMediaPanel )

end

