-- TradeTracker: Track daily profession cooldowns
-- Supports Alchemy, Tailoring, Leatherworking, and more

TradeTracker = {}
TradeTracker.db = {}

-- Cooldown database with spell IDs
local COOLDOWNS = {
    -- Alchemy Transmutes (20 hour cooldown)
    [17187] = {name = "Transmute: Arcanite", cd = 82800},
    -- [17559] = {name = "Transmute: Arcanite", cd = 72000},
    [17566] = {name = "Transmute: Classic Elements", cd = 72000, group = "classic_elem"},
    [17561] = {name = "Transmute: Classic Elements", cd = 72000, group = "classic_elem"},
    [17560] = {name = "Transmute: Classic Elements", cd = 72000, group = "classic_elem"},
    [17562] = {name = "Transmute: Classic Elements", cd = 72000, group = "classic_elem"},
    [17563] = {name = "Transmute: Classic Elements", cd = 72000, group = "classic_elem"},
    [17565] = {name = "Transmute: Classic Elements", cd = 72000, group = "classic_elem"},
    [17564] = {name = "Transmute: Classic Elements", cd = 72000, group = "classic_elem"},
    -- [17565] = {name = "Transmute: Life to Earth", cd = 72000},
    -- [17564] = {name = "Transmute: Earth to Life", cd = 72000},
    --[[ [28566] = {name = "Transmute: Primal Air to Fire", cd = 72000},
    [28567] = {name = "Transmute: Primal Earth to Water", cd = 72000},
    [28568] = {name = "Transmute: Primal Fire to Earth", cd = 72000},
    [28569] = {name = "Transmute: Primal Water to Air", cd = 72000},
    [28580] = {name = "Transmute: Primal Shadow to Water", cd = 72000},
    [28581] = {name = "Transmute: Primal Water to Shadow", cd = 72000},
    [28582] = {name = "Transmute: Primal Mana to Fire", cd = 72000},
    [28583] = {name = "Transmute: Primal Fire to Mana", cd = 72000},
    [28584] = {name = "Transmute: Primal Life to Earth", cd = 72000},
    [28585] = {name = "Transmute: Primal Earth to Life", cd = 72000},
    [53777] = {name = "Transmute: Eternal Life to Shadow", cd = 72000},
    [53776] = {name = "Transmute: Eternal Life to Fire", cd = 72000},
    [53781] = {name = "Transmute: Eternal Air to Water", cd = 72000},
    [53782] = {name = "Transmute: Eternal Air to Earth", cd = 72000},
    [53783] = {name = "Transmute: Eternal Earth to Air", cd = 72000},
    [53784] = {name = "Transmute: Eternal Earth to Shadow", cd = 72000},
    [53771] = {name = "Transmute: Eternal Fire to Water", cd = 72000},
    [53773] = {name = "Transmute: Eternal Fire to Life", cd = 72000},
    [53774] = {name = "Transmute: Eternal Shadow to Earth", cd = 72000},
    [53775] = {name = "Transmute: Eternal Shadow to Life", cd = 72000},
    [53780] = {name = "Transmute: Eternal Water to Air", cd = 72000},
    [53779] = {name = "Transmute: Eternal Water to Fire", cd = 72000},
    [60350] = {name = "Transmute: Titanium", cd = 72000}, ]]
    
    -- Tailoring (4 day cooldown on most)
    -- [36686] = {name = "Shadowcloth", cd = 345600},
    -- [31373] = {name = "Spellcloth", cd = 345600},
    -- [26751] = {name = "Primalweave", cd = 345600},
    -- [56005] = {name = "Ebonweave", cd = 345600},
    -- [56003] = {name = "Spellweave", cd = 345600},
    -- [56002] = {name = "Moonshroud", cd = 345600},
    [18560] = {name = "Mooncloth", cd = 331200},
    
    -- Leatherworking
    -- [60996] = {name = "Polar Armor Kit", cd = 72000},
    -- [60605] = {name = "Jormungar Leg Reinforcements", cd = 72000},
    -- [60607] = {name = "Nerubian Leg Reinforcements", cd = 72000},
}

-- Reverse lookup table: spell name -> spell IDs
local SPELL_NAME_TO_IDS = {}
for spellId, info in pairs(COOLDOWNS) do
    local spellName = GetSpellInfo(spellId)
    if spellName then
        if not SPELL_NAME_TO_IDS[spellName] then
            SPELL_NAME_TO_IDS[spellName] = {}
        end
        table.insert(SPELL_NAME_TO_IDS[spellName], spellId)
    end
end

-- Frame for events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("PLAYER_LOGIN")

-- Initialize saved variables
function TradeTracker:Initialize()
    if not TradeTrackerDB then
        TradeTrackerDB = {}
    end
    self.db = TradeTrackerDB
    
    -- Clean up old expired cooldowns
    local currentTime = time()
    for char, cooldowns in pairs(self.db) do
        for spellId, data in pairs(cooldowns) do
            if data.expires and data.expires < currentTime then
                cooldowns[spellId] = nil
            end
        end
    end
end

-- Get character key
function TradeTracker:GetCharKey()
    return UnitName("player") .. "|||" .. GetRealmName()
end

-- Record cooldown usage
function TradeTracker:RecordCooldown(spellId)
    local cooldownInfo = COOLDOWNS[spellId]
    if not cooldownInfo then 
        if self.debug then
            print("|cffff9900TradeTracker Debug:|r Spell ID " .. spellId .. " not found in COOLDOWNS table")
        end
        return 
    end
    
    local charKey = self:GetCharKey()
    if not self.db[charKey] then
        self.db[charKey] = {}
    end
    
    local expires = time() + cooldownInfo.cd
    
    if self.debug then
        print("|cffff9900TradeTracker Debug:|r Recording cooldown - Spell ID: " .. spellId .. ", Name: " .. cooldownInfo.name .. ", Group: " .. tostring(cooldownInfo.group))
    end
    
    self.db[charKey][spellId] = {
        name = cooldownInfo.name,
        expires = expires,
        used = time()
    }
    
    -- If this is part of a group, clear other entries in the same group
    if cooldownInfo.group then
        if self.debug then
            print("|cffff9900TradeTracker Debug:|r Clearing other entries in group: " .. cooldownInfo.group)
        end
        for sid, info in pairs(COOLDOWNS) do
            if info.group == cooldownInfo.group and sid ~= spellId then
                if self.db[charKey][sid] then
                    if self.debug then
                        print("|cffff9900TradeTracker Debug:|r Cleared spell ID: " .. sid)
                    end
                    self.db[charKey][sid] = nil
                end
            end
        end
    end
    
    print("|cff00ff00TradeTracker:|r Recorded " .. cooldownInfo.name .. " (ready in " .. SecondsToTime(cooldownInfo.cd) .. ")")
end

-- Check if cooldown is ready
function TradeTracker:IsCooldownReady(spellId)
    local charKey = self:GetCharKey()
    if not self.db[charKey] or not self.db[charKey][spellId] then
        return true
    end
    
    local data = self.db[charKey][spellId]
    return time() >= data.expires
end

-- Get time remaining
function TradeTracker:GetTimeRemaining(spellId)
    local charKey = self:GetCharKey()
    if not self.db[charKey] or not self.db[charKey][spellId] then
        return 0
    end
    
    local data = self.db[charKey][spellId]
    local remaining = data.expires - time()
    return remaining > 0 and remaining or 0
end

-- Scan for active cooldowns on login
function TradeTracker:ScanCooldowns()
    local charKey = self:GetCharKey()
    if not self.db[charKey] then
        self.db[charKey] = {}
    end
    
    -- Track which groups we've already found an active cooldown for
    local activeGroups = {}
    
    for spellId, info in pairs(COOLDOWNS) do
        -- First check if we already have valid data for this cooldown or its group
        local alreadyTracked = false
        if info.group then
            -- Check if any spell in this group is already being tracked with valid time
            for sid, cinfo in pairs(COOLDOWNS) do
                if cinfo.group == info.group and self.db[charKey][sid] then
                    local remaining = self.db[charKey][sid].expires - time()
                    if remaining > 0 and remaining <= (cinfo.cd * 1.1) then
                        alreadyTracked = true
                        if self.debug then
                            print("|cffff9900TradeTracker Debug:|r Skipping scan for " .. info.name .. " - already tracked with valid data")
                        end
                        break
                    end
                end
            end
        elseif self.db[charKey][spellId] then
            local remaining = self.db[charKey][spellId].expires - time()
            if remaining > 0 and remaining <= (info.cd * 1.1) then
                alreadyTracked = true
                if self.debug then
                    print("|cffff9900TradeTracker Debug:|r Skipping scan for " .. info.name .. " - already tracked with valid data")
                end
            end
        end
        
        if not alreadyTracked then
            local start, duration = GetSpellCooldown(spellId)
            if start and start > 0 and duration and duration > 0 then
                -- Cooldown is active
                local remaining = duration - (GetTime() - start)
                
                -- Sanity check: ignore cooldowns longer than expected (bad data from game)
                local maxExpected = info.cd * 1.1 -- Allow 10% margin
                if remaining > maxExpected then
                    if self.debug then
                        print("|cffff9900TradeTracker Debug:|r Ignoring " .. info.name .. " - cooldown too long (" .. SecondsToTime(remaining) .. " vs expected " .. SecondsToTime(info.cd) .. ")")
                    end
                elseif remaining > 2 then -- Ignore GCD (1.5s)
                    -- If this spell is part of a group
                    if info.group then
                        -- Check if we already found an active cooldown for this group
                        if activeGroups[info.group] then
                            -- We already have one, keep the one with more time remaining (most accurate)
                            if remaining > activeGroups[info.group].remaining then
                                -- This one has more time, clear the old one and use this
                                self.db[charKey][activeGroups[info.group].spellId] = nil
                                activeGroups[info.group] = {spellId = spellId, remaining = remaining}
                                
                                self.db[charKey][spellId] = {
                                    name = info.name,
                                    expires = time() + remaining,
                                    used = time() - (duration - remaining)
                                }
                            end
                            -- Otherwise ignore this one, we already have a better entry
                        else
                            -- First one we found for this group
                            activeGroups[info.group] = {spellId = spellId, remaining = remaining}
                            
                            -- Clear any old entries from this group first
                            for sid, cinfo in pairs(COOLDOWNS) do
                                if cinfo.group == info.group then
                                    self.db[charKey][sid] = nil
                                end
                            end
                            
                            -- Now add this one
                            self.db[charKey][spellId] = {
                                name = info.name,
                                expires = time() + remaining,
                                used = time() - (duration - remaining)
                            }
                            
                            if self.debug then
                                print("|cff00ff00TradeTracker:|r Found active cooldown: " .. info.name .. " (" .. SecondsToTime(remaining) .. " remaining)")
                            end
                        end
                    else
                        -- Not part of a group, just update normally
                        if not self.db[charKey][spellId] or self.db[charKey][spellId].expires < (time() + remaining) then
                            self.db[charKey][spellId] = {
                                name = info.name,
                                expires = time() + remaining,
                                used = time() - (duration - remaining)
                            }
                            if self.debug then
                                print("|cff00ff00TradeTracker:|r Found active cooldown: " .. info.name .. " (" .. SecondsToTime(remaining) .. " remaining)")
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Show cooldown status
function TradeTracker:ShowStatus()
    print("|cff00ff00=== TradeTracker ===|r")
    
    if not self.db or next(self.db) == nil then
        print("No cooldowns tracked yet.")
        return
    end
    
    local currentTime = time()
    local currentRealm = GetRealmName()
    local hasAnyCooldowns = false
    
    if self.debug then
        print("Debug: Current realm = " .. currentRealm)
        print("Debug: Checking characters...")
    end
    
    -- Iterate through all characters
    for charKey, cooldowns in pairs(self.db) do
        if self.debug then
            print("Debug: Found character: " .. charKey)
        end
        
        -- Only show characters from current realm
        local charName, realm = charKey:match("^(.+)|||(.+)$")
        
        if self.debug then
            print("Debug: Parsed name=" .. tostring(charName) .. ", realm=" .. tostring(realm))
        end
        
        if realm == currentRealm and next(cooldowns) ~= nil then
            local cooldownLines = {}
            
            if self.debug then
                print("Debug: Character matches realm, checking cooldowns...")
            end
            
            -- Collect cooldown info for this character
            for spellId, data in pairs(cooldowns) do
                if self.debug then
                    print("Debug: Spell ID " .. spellId .. " found, expires=" .. data.expires .. ", current=" .. currentTime)
                end
                
                local remaining = data.expires - currentTime
                if remaining > 0 then
                    hasAnyCooldowns = true
                    table.insert(cooldownLines, "|cffffd700" .. data.name .. ":|r " .. SecondsToTime(remaining))
                else
                    hasAnyCooldowns = true
                    table.insert(cooldownLines, "|cff00ff00" .. data.name .. ":|r Ready!")
                end
            end
            
            -- Print character header and cooldowns if any exist
            if #cooldownLines > 0 then
                local currentChar = self:GetCharKey()
                if charKey == currentChar then
                    print("|cff00ccff" .. charName .. " (current):|r")
                else
                    print("|cff00ccff" .. charName .. ":|r")
                end
                
                for _, line in ipairs(cooldownLines) do
                    print("  " .. line)
                end
            end
        end
    end
    
    if not hasAnyCooldowns then
        print("All tracked cooldowns are ready!")
    end
end

-- Debug mode
TradeTracker.debug = false

-- Slash command handler
SLASH_TRADETRACKER1 = "/tradetracker"
SLASH_TRADETRACKER2 = "/tt"
SlashCmdList["TRADETRACKER"] = function(msg)
    if msg == "status" or msg == "" then
        TradeTracker:ShowStatus()
    elseif msg == "clear" then
        local charKey = TradeTracker:GetCharKey()
        TradeTracker.db[charKey] = {}
        print("|cff00ff00TradeTracker:|r All cooldowns cleared.")
    elseif msg == "debug" then
        TradeTracker.debug = not TradeTracker.debug
        print("|cff00ff00TradeTracker:|r Debug mode " .. (TradeTracker.debug and "enabled" or "disabled"))
    elseif msg == "scan" then
        TradeTracker:ScanCooldowns()
        print("|cff00ff00TradeTracker:|r Cooldown scan complete.")
    else
        print("|cff00ff00TradeTracker Commands:|r")
        print("/tradetracker or /tt - Show cooldown status")
        print("/tt clear - Clear all cooldowns")
        print("/tt scan - Scan for active cooldowns now")
        print("/tt debug - Toggle debug mode")
    end
end

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "TradeTracker" then
            TradeTracker:Initialize()
            print("|cff00ff00TradeTracker|r loaded. Type /tt for status.")
        end
    elseif event == "PLAYER_LOGIN" then
        TradeTracker:Initialize()
        -- Scan for active cooldowns after a short delay (let spellbook load)
        C_Timer.After(2, function()
            TradeTracker:ScanCooldowns()
        end)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, spellName, _, _, spellId = ...
        if unit == "player" then
            if TradeTracker.debug then
                print("|cffff9900TradeTracker Debug:|r Spell cast - ID: " .. tostring(spellId) .. ", Name: " .. tostring(spellName))
            end
            
            -- If spellId is nil, try to look it up by name
            if not spellId and spellName and SPELL_NAME_TO_IDS[spellName] then
                if TradeTracker.debug then
                    print("|cffff9900TradeTracker Debug:|r Looking up spell by name: " .. spellName)
                end
                -- Use the first matching spell ID
                spellId = SPELL_NAME_TO_IDS[spellName][1]
                if TradeTracker.debug then
                    print("|cffff9900TradeTracker Debug:|r Found spell ID: " .. tostring(spellId))
                end
            end
            
            if spellId and COOLDOWNS[spellId] then
                TradeTracker:RecordCooldown(spellId)
            elseif TradeTracker.debug and spellName and SPELL_NAME_TO_IDS[spellName] then
                print("|cffff9900TradeTracker Debug:|r Spell tracked but recording failed")
            end
        end
    end
end)