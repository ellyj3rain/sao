--------------------------------------------------------------------------------------------------
--		----	  |			  |			|		 |				|    --    |      ----			--
--		----	  |			  |			|		 |				|    --	   |      ----			--
--		----	  |		-------	   -----|	 ---------		-----          -      ----	   -------
--		----	  |			---			|		 -----		------        --      ----			--
--		----	  |			---			|		 -----		-------	 	 ---      ----			--
--		----	  |		-------	   ----------	 -----		-------		 ---      ----	   -------
--			|	  |		-------			|		 -----		-------		 ---		  |			--
--			|	  |		-------			|	 	 -----		-------		 ---		  |			--
--------------------------------------------------------------------------------------------------

function PartnerStopDance(DanceTarget)

	if (DanceTarget:hasModData()) then

	if not DanceTarget:getModData().IsDancingInit then
	return
	end

	if not DanceTarget:getModData().IsDancingFull then
	return
	end
	
	DanceTarget:getModData().PartnerStopped = true

	end
end

function PartnerFaceProposer(DancePartner, ProposerX, ProposerY)

	if (DancePartner:hasModData()) then

	if not DancePartner:getModData().IsDancingInit then
	return
	end

	if not DancePartner:getModData().IsDancingFull then
	return
	end
	
	DancePartner:faceLocation(ProposerX, ProposerY)
	DancePartner:faceLocationF(ProposerX, ProposerY)

	end
end

function PlayerDanceWasAccepted(DanceProposer, DancePartner, PartnerX, PartnerY)

	if (DanceProposer:hasModData()) then

	--if not DanceProposer:getModData().IsDancingInit then
	--sendClientCommand(DanceProposer, "LS", "StopDance", {DancePartner:getOnlineID()})
	--return
	--end

	--if DanceProposer:getModData().IsDancingFull ~= nil and
	--DanceProposer:getModData().IsDancingFull == true then
	--sendClientCommand(DanceProposer, "LS", "StopDance", {DancePartner:getOnlineID()})
	--return
	--end
	
    for playerIndex = 0, getNumActivePlayers()-1 do
        local playersList = {};--get players
		local playerObj = getSpecificPlayer(playerIndex)
		if (playerObj ~= nil) then
			for x = playerObj:getX()-1,playerObj:getX()+1 do
                for y = playerObj:getY()-1,playerObj:getY()+1 do
                    local square = getCell():getGridSquare(x,y,playerObj:getZ());
                    if square then
                        for i = 0,square:getMovingObjects():size()-1 do
                            local moving = square:getMovingObjects():get(i);
                            if instanceof(moving, "IsoPlayer") then
                                table.insert(playersList, moving);
                            end
                        end
                    end
                end
            end
		end
		
        if #playersList > 0 then
			if not playerObj:getModData().IsDancingFull then
			for i,v in ipairs(playersList) do
				if v:getUsername() ~= playerObj:getUsername() and
				tostring(v:getUsername()) == DancePartner then
					sendClientCommand(playerObj, "LS", "StopDance", {v:getOnlineID()})
				end
			end
			end
			if playerObj:getModData().IsDancingFullPartner ~= nil and
			playerObj:getModData().IsDancingFullPartner == true then
			for i,v in ipairs(playersList) do
				if v:getUsername() ~= playerObj:getUsername() and
				tostring(v:getUsername()) == DancePartner then
					sendClientCommand(playerObj, "LS", "StopDance", {v:getOnlineID()})
				end
			end
			end
        end			
    end
	
	DanceProposer:getModData().DancingPartner = DancePartner
	local ProposerX = DanceProposer:getX()
	local ProposerY = DanceProposer:getY()

	local correctX
	local correctY

	if ProposerX > PartnerX and ProposerY > PartnerY then--Proposer is looking up, move Proposer below Partner 
	
	correctX = PartnerX + 0.5
	correctY = PartnerY + 0.5
	
	elseif ProposerX > PartnerX and ProposerY < PartnerY then--Proposer is looking left, move Proposer to the right of Partner 
	
	correctX = PartnerX + 0.5
	correctY = PartnerY - 0.5
	
	elseif ProposerX > PartnerX and ProposerY == PartnerY then--Proposer is looking up/left, move Proposer to below/right of Partner, unlikely 
	
	correctX = PartnerX + 0.5
	correctY = PartnerY
	
	elseif ProposerX < PartnerX and ProposerY == PartnerY then--Proposer is looking down/right, move Proposer to above/left of Partner, unlikely 
	
	correctX = PartnerX - 0.5
	correctY = PartnerY

	elseif ProposerY < PartnerY and ProposerX < PartnerX then--Proposer is down, move Proposer above Partner
	
	correctX = PartnerX - 0.5
	correctY = PartnerY - 0.5

	elseif ProposerY > PartnerY and ProposerX < PartnerX then--Proposer is looking right, move Proposer to the left of Partner
	
	correctX = PartnerX - 0.5
	correctY = PartnerY + 0.5

	elseif ProposerY > PartnerY and ProposerX == PartnerX then--Proposer is looking up/right, move Proposer to down/left of Partner, unlikely 
	
	correctX = PartnerX
	correctY = PartnerY + 0.5

	elseif ProposerY < PartnerY and ProposerX == PartnerX then--Proposer is looking down/left, move Proposer to above/right of Partner, unlikely 
	
	correctX = PartnerX
	correctY = PartnerY - 0.5

	elseif ProposerY == PartnerY and ProposerX == PartnerX then--Proposer is in the same coord as Partner, move it to below Partner, very unlikely
	
	correctX = PartnerX + 0.5
	correctY = PartnerY + 0.5
	
	else--failsafe
	
	correctX = PartnerX + 0.5
	correctY = PartnerY + 0.5

	end
	
    --if ProposerY - 0.5 ~= PartnerY or ProposerX - 0.5 ~= PartnerX then
  

    DanceProposer:setX(correctX)
    DanceProposer:setY(correctY)
	--DanceProposer:setLx(correctX)
    --DanceProposer:setLy(correctY)
	
	DanceProposer:faceLocation(PartnerX, PartnerY)
	DanceProposer:faceLocationF(PartnerX, PartnerY)
	--
	local PX = tonumber(DanceProposer:getX())
	local PY = tonumber(DanceProposer:getY())

    for playerIndex = 0, getNumActivePlayers()-1 do
        local playersList = {};--get players
		local playerObj = getSpecificPlayer(playerIndex)
		if (playerObj ~= nil) then
			for x = playerObj:getX()-1,playerObj:getX()+1 do
                for y = playerObj:getY()-1,playerObj:getY()+1 do
                    local square = getCell():getGridSquare(x,y,playerObj:getZ());
                    if square then
                        for i = 0,square:getMovingObjects():size()-1 do
                            local moving = square:getMovingObjects():get(i);
                            if instanceof(moving, "IsoPlayer") then
                                table.insert(playersList, moving);
                            end
                        end
                    end
                end
            end
		end
	
        if #playersList > 0 then
			for i,v in ipairs(playersList) do
				if v:getUsername() ~= playerObj:getUsername() and
				tostring(v:getUsername()) == DancePartner then
					sendClientCommand(playerObj, "LS", "FaceDanceProposer", {v:getOnlineID(), PX, PY})
				end
			end
        end			
    end
	
    --end
	DanceProposer:getModData().IsDancingPartner = "source"
	DanceProposer:getModData().IsDancingFullPartner = true
	end
end

function PlayerIsAskedToDance(DanceTarget, DanceProposer)

	if (DanceTarget:hasModData()) then

	if not DanceTarget:getModData().IsDancingFull then
	return
	end
	
	if not DanceTarget:getModData().WantsToDance then
	return
	end

	if DanceTarget:getModData().IsDancingFullPartner ~= nil and
	DanceTarget:getModData().IsDancingFullPartner == true then
	return
	end
	
	DanceTarget:getModData().DancingPartner = DanceProposer
	local PartnerX = tonumber(DanceTarget:getX())
	local PartnerY = tonumber(DanceTarget:getY())

    for playerIndex = 0, getNumActivePlayers()-1 do
        local playersList = {};--get players
		local playerObj = getSpecificPlayer(playerIndex)
		local dancePartner = tostring(playerObj:getUsername())
		if (playerObj ~= nil) then
			for x = playerObj:getX()-1,playerObj:getX()+1 do
                for y = playerObj:getY()-1,playerObj:getY()+1 do
                    local square = getCell():getGridSquare(x,y,playerObj:getZ());
                    if square then
                        for i = 0,square:getMovingObjects():size()-1 do
                            local moving = square:getMovingObjects():get(i);
                            if instanceof(moving, "IsoPlayer") then
                                table.insert(playersList, moving);
                            end
                        end
                    end
                end
            end
		end
	
        if #playersList > 0 then
			for i,v in ipairs(playersList) do
				if v:getUsername() ~= playerObj:getUsername() and
				tostring(v:getUsername()) == DanceProposer then
					sendClientCommand(playerObj, "LS", "AcceptedDance", {v:getOnlineID(), dancePartner, PartnerX, PartnerY})
				end
			end
        end			
    end
	DanceTarget:getModData().IsDancingPartner = "target"
	DanceTarget:getModData().IsDancingFullPartner = true
	end
end

function PlayerOtherPlayerIsDancingResponse(DanceProposer, IsDancing)

	if (DanceProposer:hasModData()) then
	
		if IsDancing == true then
			DanceProposer:getModData().OtherPlayersAroundDancing = DanceProposer:getModData().OtherPlayersAroundDancing + 1
		end
	end
	
end

function PlayerIsAskedIfIsDancing(DanceTarget, DanceProposer)

	if (DanceTarget:hasModData()) then

	local IsDancing = false

	if not DanceTarget:getModData().IsDancingFull then
	IsDancing = true
	end

	if DanceTarget:getModData().IsDancingFullPartner ~= nil and
	DanceTarget:getModData().IsDancingFullPartner == true then
	IsDancing = true
	end

    for playerIndex = 0, getNumActivePlayers()-1 do
        local playersList = {};--get players
		local playerObj = getSpecificPlayer(playerIndex)
		if (playerObj ~= nil) then
			for x = playerObj:getX()-8,playerObj:getX()+8 do
                for y = playerObj:getY()-8,playerObj:getY()+8 do
                    local square = getCell():getGridSquare(x,y,playerObj:getZ());
                    if square then
                        for i = 0,square:getMovingObjects():size()-1 do
                            local moving = square:getMovingObjects():get(i);
                            if instanceof(moving, "IsoPlayer") then
                                table.insert(playersList, moving);
                            end
                        end
                    end
                end
            end
		end
	
        if #playersList > 0 then
			for i,v in ipairs(playersList) do
				if v:getUsername() ~= playerObj:getUsername() and
				tostring(v:getUsername()) == DanceProposer then
					sendClientCommand(playerObj, "LS", "OtherPlayerIsDancing", {v:getOnlineID(), IsDancing})
				end
			end
        end			
    end
	end
end
