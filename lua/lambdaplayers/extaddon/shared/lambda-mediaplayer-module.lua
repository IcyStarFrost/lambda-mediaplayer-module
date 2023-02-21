local random = math.random
local rand = math.Rand
local IsValid = IsValid
local CurTime = CurTime


local function Initialize( self )

    self.l_mediaplayer = nil -- The Media Player we are currently watching
    self.l_desiredwatchposition = nil -- The position away from the media player we want to watch from
    self.l_watchendtime = 0
    self.l_randomwatchline = 0

    function self:WatchingMediaPlayer()
        if !IsValid( self.l_mediaplayer ) then self:SetState( "Idle" ) self.l_nextidlesound = CurTime() + 5 return end
        self.l_nextidlesound = math.huge

        self:LookTo( self.l_mediaplayer, 3 )

        local pos = self.l_mediaplayer:GetPos() + self.l_mediaplayer:GetForward() * self.l_desiredwatchposition[ 1 ] + self.l_mediaplayer:GetRight() * self.l_desiredwatchposition[ 2 ]

        if self:GetRangeSquaredTo( pos ) > ( 30 * 30 ) then
            self:MoveToPos( pos )
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
            self.l_nextidlesound = CurTime() + 5
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