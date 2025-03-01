--[[
    written by sorgis, turtle wow server, 2023
    https://github.com/sorgis-sorgis/sorgis_raid_marks
]]

---------------------
-- IMPLEMENTATION
---------------------
local _G = _G or getfenv(0)
local srm = _G.srm or {}

local has_superwow = SetAutoloot and true or false

local markIndex = {
    ["star"] = 1,
    ["circle"] = 2,
    ["diamond"] = 3,
    ["triangle"] = 4,
    ["moon"] = 5,
    ["square"] = 6,
    ["cross"] = 7,
    ["skull"] = 8,
}

local function MarkUnit(unit,mark)
    if has_superwow and not IsRaidOfficer() and not IsPartyLeader() then
        SetRaidTarget(unit, mark, 1)
    else
        SetRaidTarget(unit, mark)
    end
end

do
    local make_logger = function(r, g, b)
        return function(...)
            local msg = ""
            for i, v in ipairs(arg) do
                msg = msg .. tostring(v) 
            end

            DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)
        end
    end

    srm.log = make_logger(1, 1, 0.5)
    srm.error = make_logger(1, 0, 0)
end

srm.makeSlashCommand = function(aName, aBehaviour)
    local _G = _G or getfenv(0)
    local nameUpperCase = string.upper(aName)
    _G["SLASH_" .. nameUpperCase .. 1] = "/" .. aName
    SlashCmdList[nameUpperCase] = aBehaviour
end

srm.unitIsAlive = function(aUnitID)
    return UnitIsDead(aUnitID) == nil
end

srm.unitExists = function(aUnitID) 
    return UnitExists(aUnitID) ~= nil 
end

srm.unitHasRaidMark = function(aUnitID, aMark)
    local unitMark = ({
        [1] = "star",
        [2] = "circle",
        [3] = "diamond",
        [4] = "triangle",
        [5] = "moon",
        [6] = "square",
        [7] = "cross",
        [8] = "skull",
    })[GetRaidTargetIndex(aUnitID)] or nil

    return aMark == unitMark
end

srm.markUnitWithRaidMark = function(aMark, aUnitID)
    aUnitID = aUnitID or "target"

    if not srm.unitExists(aUnitID) then return end
    if not markIndex[aMark] then return end

    MarkUnit(aUnitID, markIndex[aMark])
end

srm.playerIsInRaid = function()
    return GetNumRaidMembers() ~= 0
end

srm.playerIsInParty = function()
    return not srm.playerIsInRaid() and GetNumPartyMembers() ~= 0
end

-- interrupt block
-- this will be for clicking to use an interrupt on the mark
-- I need to scan the spellbook 'once' and find the relevant interrupt
do
    srm.interruptUnit = function(guid)
        local interrupts = {
            ["MAGE"] = "Counterspell",
            ["ROGUE"] = "Kick",
            ["WARRIOR"] = "Pummel",
            -- ["WARRIOR"] = "Shield Bash",
            ["SHAMAN"]  = "Earth Shock(Rank 1)",
        }

        local _,class = UnitClass("player")
        local formIndex

        interruptSpell = interrupts[class]

        if class == "WARRIOR" then
            for i = 1, GetNumShapeshiftForms() do
                local _, name, active = GetShapeshiftFormInfo(i)
                if active then
                    formIndex = i
                    break
                end
            end
            if formIndex == 1 or formIndex == 2 then
                interruptSpell = "Shield Bash"
            end
        end

        if class == "MAGE" or class == "SHAMAN" then
            SpellStopCasting()
        end
        CastSpellByName(interruptSpell,guid)
    end
end

do
    local getAttackSlotIndex
    do
        local attackSlotIndex
        getAttackSlotIndex = function()
            if attackSlotIndex == nil then
                for slotIndex = 1, 120 do 
                    if IsAttackAction(slotIndex) then
                        attackSlotIndex = slotIndex
                        break
                    end
                end
            end

            return attackSlotIndex
        end

        local frame = CreateFrame("FRAME")
        frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        frame:SetScript("OnEvent", function()
            if event == "ACTIONBAR_SLOT_CHANGED" then
                attackSlotIndex = nil
            end
        end)
    end

    srm.startAttack = function()
        local attackSlotIndex = getAttackSlotIndex()

        if not attackSlotIndex then 
            srm.error("sorgis_raid_marks startAttack requires the attack ability to be somewhere in the actionbars") 
            return
        end

        if not IsCurrentAction(attackSlotIndex) then 
            UseAction(attackSlotIndex)
        end
    end
end

do
    local PLAYER_UNIT_IDS = {
        [1] = "player",
        [2] = "target",
        [3] = "targettarget",
        [4] = "mouseover",
        [5] = "mouseovertarget",
        [6] = "pet",
        [7] = "pettarget",
        [8] = "pettargettarget",
    }

    local RAID_UNIT_IDS = (function()
        local units = {}
        
        for i = 1, 40 do table.insert(units, "raid" .. i) end
        for i = 1, 40 do table.insert(units, "raid" .. i .. "target") end
        for i = 1, 40 do table.insert(units, "raid" .. i .. "targettarget") end
        for i = 1, 40 do table.insert(units, "raidpet" .. i) end
        for i = 1, 40 do table.insert(units, "raidpet" .. i .. "target") end
        for i = 1, 40 do table.insert(units, "raidpet" .. i .. "targettarget") end

        return units
    end)()

    local PARTY_UNIT_IDS = (function()
        local units = {}

        for i = 1, 5 do table.insert(units, "party" .. i) end
        for i = 1, 5 do table.insert(units, "party" .. i .. "target") end
        for i = 1, 5 do table.insert(units, "party" .. i .. "targettarget") end
        for i = 1, 5 do table.insert(units, "partypet" .. i) end
        for i = 1, 5 do table.insert(units, "partypet" .. i .. "target") end
        for i = 1, 5 do table.insert(units, "partypet" .. i .. "targettarget") end
        
        return units
    end)()

    srm.visitUnitIDs = function(aVisitor)
        for _, aUnitID in pairs(PLAYER_UNIT_IDS) do
            if aVisitor(aUnitID) == true then return true end
        end

        for _, aUnitID in pairs(srm.playerIsInRaid() and RAID_UNIT_IDS or 
            srm.playerIsInParty() and PARTY_UNIT_IDS or {}) do
            if aVisitor(aUnitID) == true then return true end
        end

        return false
    end

    srm.tryTargetUnitWithRaidMarkFromGroupMembers = function(aMark)
        return srm.visitUnitIDs(function(aUnitID)
            if srm.unitHasRaidMark(aUnitID, aMark) and srm.unitIsAlive(aUnitID) then
                TargetUnit(aUnitID)   
                return true
            end
        end)
    end
end

do
    local visitNamePlates 
    do
        local namePlates = {} 
        local lastWorldFrameChildCount = 0

        visitNamePlates = function(aVisitor)
            local getNamePlates = function()
                local worldFrameChildCount = WorldFrame:GetNumChildren()
                if lastWorldFrameChildCount < worldFrameChildCount then
                    local worldFrames = {WorldFrame:GetChildren()}
                    for index = lastWorldFrameChildCount, worldFrameChildCount do
                        local plate = worldFrames[index]
                        if plate ~= nil and plate:GetName() == nil then
                            -- This is a standard vanilla wow nameplate
                            if plate["name"] then
                                namePlates[plate] = true
                            else
                                -- this is a modified pfUI/Shagu nameplate
                                local _, shaguplate = plate:GetChildren()
                                if shaguplate ~= nil and type(shaguplate.platename) == "string" then
                                    local adapterplate = {}
                                    adapterplate.IsVisible = function(self) 
                                        return shaguplate:IsVisible()
                                    end
                                    adapterplate.Click = function(self)
                                        plate:Click() 
                                    end
                                    adapterplate.raidicon = shaguplate.raidicon

                                    namePlates[adapterplate] = true
                                end
                            end
                        end
                    end

                    lastWorldFrameChildCount = worldFrameChildCount
                end

                return namePlates
            end

            for plate, _ in pairs(getNamePlates()) do
                if plate:IsVisible() ~= nil then
                    if aVisitor(plate) == true then return true end
                end
            end

            return false
        end
    end

    local raidIconUVsToMarkName = function(aU, aV)
        local key = tostring(aU) .. "," .. tostring(aV)
        local UV_TO_RAID_ICONS = {
            ["0.75,0.25"] = "skull", 
            ["0.5,0.25"] = "cross", 
            ["0,0.25"] = "moon", 
            ["0,0"] = "star", 
            ["0.75,0"] = "triangle", 
            ["0.25,0"] = "circle", 
            ["0.25,0.25"] = "square", 
            ["0.5,0"] = "diamond", 
        }
        return UV_TO_RAID_ICONS[key]
    end

    srm.tryTargetRaidMarkInNamePlates = function(aRaidMark)
        return visitNamePlates(function(plate)
            if plate.raidicon:IsVisible() ~= nil then 
                local u, v = plate.raidicon:GetTexCoord()
                if raidIconUVsToMarkName(u, v) == aRaidMark then
                    plate:Click() 
                    return true
                end
            end
        end)
    end
end

srm.tryTargetMark = function(aRaidMark)
    if has_superwow then
        local m = "mark"..markIndex[aRaidMark]
        if UnitExists(m) then
            TargetUnit(m)
            return true
        end
    else
        return srm.tryTargetUnitWithRaidMarkFromGroupMembers(aRaidMark) or
            srm.tryTargetRaidMarkInNamePlates(aRaidMark)
    end
end

srm.tryAttackMark = function(aRaidMark)
    if srm.tryTargetMark(aRaidMark) then

        -- srm.startAttack()
        AttackTarget()
        return true
    end

    return false
end

---------------------
-- BINDINGS
---------------------
BINDING_HEADER_SORGIS_RAID_MARKS = "Sorgis Raid Marks"
BINDING_NAME_TRY_TARGET_STAR = "Try to target star"
BINDING_NAME_TRY_TARGET_CIRCLE = "Try to target circle"
BINDING_NAME_TRY_TARGET_DIAMOND = "Try to target diamond"
BINDING_NAME_TRY_TARGET_TRIANGLE = "Try to target triangle"
BINDING_NAME_TRY_TARGET_MOON = "Try to target moon"
BINDING_NAME_TRY_TARGET_SQUARE = "Try to target square"
BINDING_NAME_TRY_TARGET_CROSS = "Try to target cross"
BINDING_NAME_TRY_TARGET_SKULL = "Try to target skull"
SorgisRaidMarks_TryTargetMark = function(aMark)
    srm.tryTargetMark(aMark)
end

-----------------------
-- MACRO SLASH COMMANDS
-----------------------
srm.makeSlashCommand("trytargetmark", function(msg)
    msg = string.lower(msg)

    srm.tryTargetMark(msg)
end)

srm.makeSlashCommand("tryattackmark", function(msg)
    msg = string.lower(msg)

    srm.tryAttackMark(msg)
end)

srm.makeSlashCommand("setmark", function(msg)
    local matches = string.gfind(msg, "\(%w+\)")

    local mark = matches()
    local unitID = matches()

    srm.markUnitWithRaidMark(mark, unitID)
end)

--------------------
-- USER INTERFACE
--------------------
do
    --------------------
    -- Target tray GUI
    --------------------
    local gui = (function()
        local rootFrame = CreateFrame("Frame", nil, UIParent)
        rootFrame:SetWidth(1)
        rootFrame:SetHeight(1)
        rootFrame:SetPoint("TOPLEFT", 0,0)
        rootFrame:SetMovable(true)

        local cast_log = {}

        local makeRaidMarkFrame = function(aX, aY, aMark)
            local SIZE = 32

            local frame = CreateFrame("Button", nil, rootFrame)
            frame:SetFrameStrata("BACKGROUND")
            frame:SetWidth(SIZE) 
            frame:SetHeight(SIZE)
            frame:SetPoint("CENTER", aX * SIZE, aY * SIZE)
            frame:Show() 

            do
                frame:EnableMouse(true)
                frame:RegisterForClicks("LeftButtonDown", "RightButtonDown") -- click on down
                frame:SetScript("OnClick", function()
                    if arg1 == "LeftButton" then
                        if IsControlKeyDown() then
                            local _,guid = UnitExists("mark"..markIndex[aMark])
                            if guid and (UnitIsUnit("target", guid) or not UnitExists("target")) then
                                MarkUnit(guid, 0)
                            else
                                srm.markUnitWithRaidMark(aMark)
                            end
                        else
                            srm.tryTargetMark(aMark)
                        end
                    elseif arg1 == "RightButton" then
                        if has_superwow and IsShiftKeyDown() then
                            srm.interruptUnit("mark"..markIndex[aMark])
                        else
                            srm.tryAttackMark(aMark)
                        end
                        -- srm.tryAttackMark(aMark)
                    end
                end)
            end

            local raidMark = {}

            frame:RegisterForDrag("LeftButton")
            frame:SetMovable(true)
            frame:SetScript("OnDragStart", function()
                if rootFrame:IsMovable() then
                    rootFrame:StartMoving()
                end
            end)
            frame:SetScript("OnDragStop", function()
                if rootFrame:IsMovable() then
                    srm.log("raidtray moved. type `", _G.SLASH_SRAIDMARKS1, "` to lock or hide")
                end

                rootFrame:StopMovingOrSizing()

                raidMark.onDragStop()
            end)

            local raidMarkTexture = frame:CreateTexture(nil, "ARTWORK")
            raidMarkTexture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
            raidMarkTexture:SetPoint("CENTER", 0, 0)
            raidMarkTexture:SetWidth(SIZE)
            raidMarkTexture:SetHeight(SIZE)

            local castHighlightTexture
            if has_superwow then
                castHighlightTexture = frame:CreateTexture(nil, "OVERLAY")
                castHighlightTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
                castHighlightTexture:SetVertexColor(1,1,1,0.6)
                castHighlightTexture:SetPoint("BOTTOM", 0, 0)
                castHighlightTexture:SetWidth(SIZE)
                castHighlightTexture:SetHeight(SIZE)
            end

            local markNameToTextCoords = {
                ["star"]     = {0.00,0.25,0.00,0.25},
                ["circle"]   = {0.25,0.50,0.00,0.25},
                ["diamond"]  = {0.50,0.75,0.00,0.25},
                ["triangle"] = {0.75,1.00,0.00,0.25},
                ["moon"]     = {0.00,0.25,0.25,0.50},
                ["square"]   = {0.25,0.50,0.25,0.50},
                ["cross"]    = {0.50,0.75,0.25,0.50},
                ["skull"]    = {0.75,1.00,0.25,0.50},
            }
            raidMarkTexture:SetTexCoord(unpack(markNameToTextCoords[aMark]))

            raidMark.setScale = function(aScale)
                frame:SetWidth(aScale) 
                frame:SetHeight(aScale)
                frame:SetPoint("CENTER", aX * aScale, aY * aScale)
                raidMarkTexture:SetWidth(aScale)
                raidMarkTexture:SetHeight(aScale)
                if has_superwow then
                    castHighlightTexture:SetWidth(aScale)
                    castHighlightTexture:SetHeight(aScale)
                end
            end
            raidMark.getScale = function(aScale)
                return frame:GetWidth()
            end
            raidMark.onDragStop = function() end
            raidMark.setColor = function(r,g,b,a) raidMarkTexture:SetVertexColor(r,g,b,a) end
            if has_superwow then
                raidMark.setCastHighlightHeight = function (h) castHighlightTexture:SetHeight(h ~= 0 and h or -8) end
            end
            raidMark.setPosition = function(x,y)
                frame:SetPoint("CENTER", x * frame:GetWidth(), y * frame:GetWidth())
            end

            if has_superwow then
                raidMark.setCastTexture = function(t) castHighlightTexture:SetTexture(t) end
            end

            return raidMark
        end


        local trayButtons = {}
        table.insert(trayButtons, makeRaidMarkFrame(0,0, "star"))
        table.insert(trayButtons, makeRaidMarkFrame(1,0, "circle"))
        table.insert(trayButtons, makeRaidMarkFrame(2,0, "diamond"))
        table.insert(trayButtons, makeRaidMarkFrame(3,0, "triangle"))
        table.insert(trayButtons, makeRaidMarkFrame(4,0, "moon"))
        table.insert(trayButtons, makeRaidMarkFrame(5,0, "square"))
        table.insert(trayButtons, makeRaidMarkFrame(6,0, "cross"))
        table.insert(trayButtons, makeRaidMarkFrame(7,0, "skull"))

        if has_superwow then
            local elapsed = 0
            local rm = nil
            local newHeight = 0
            rootFrame:SetScript("OnUpdate", function ()
                elapsed = elapsed + arg1
                if elapsed > 0.05 then
                    elapsed = 0
                    for i=1,8 do
                        newHeight = 0
                        rm = trayButtons[i]
                        if rm.guid and UnitExists(rm.guid) and (not UnitIsDead(rm.guid) or UnitIsPlayer(rm.guid)) then
                            if sorgis_raid_marks.show_casts and (not UnitIsPlayer(rm.guid) or sorgis_raid_marks.player_casts) then
                                if cast_log[rm.guid] then
                                    local elapsed = cast_log[rm.guid].start + cast_log[rm.guid].duration - GetTime()
                                    newHeight = ((elapsed > 0 and elapsed or 0) / cast_log[rm.guid].duration) * (rm.getScale())
                                    rm.setCastTexture(cast_log[rm.guid].texture)
                                end
                            end
                            rm.setColor(1,1,1,1)
                        else
                            rm.setColor(1,1,1,sorgis_raid_marks.fadeunmarked/100)
                        end
                        rm.setCastHighlightHeight(newHeight)
                    end
                end
            end)
        end
        local gui = {}

        gui.getScale = function()
            return trayButtons[1].getScale()
        end
        gui.setScale = function(aScale)
            for _, button in pairs(trayButtons) do
                button.setScale(aScale)
            end

            sorgis_raid_marks.scale = gui.getScale()
        end

        gui.getVisibility = function()
            return rootFrame:IsVisible() ~= nil
        end
        gui.setVisibility = function(aVisibility)
            if aVisibility then
                rootFrame:Show()
            else
                rootFrame:Hide()
            end

            sorgis_raid_marks.visibility = gui.getVisibility()
        end

        gui.lock = function()
            rootFrame:SetMovable(false)
            rootFrame:StopMovingOrSizing()

            sorgis_raid_marks.locked = gui.getMovable() ~= true
        end
        gui.unlock = function()
            rootFrame:SetMovable(true)

            sorgis_raid_marks.locked = gui.getMovable() ~= true
        end

        gui.getMovable = function()
            return rootFrame:IsMovable() ~= nil
        end
        gui.setMovable = function(aMovable)
            rootFrame:SetMovable(aMovable)
        end

        gui.getPosition = function()
            local a, b, c, x, y = rootFrame:GetPoint()
            
            return x, y
        end
        gui.setPosition = function(x, y)
            rootFrame:SetPoint("TOPLEFT", x, y)

            sorgis_raid_marks.position = {gui.getPosition()} 
        end
        for _, button in pairs(trayButtons) do
            button.onDragStop = function()
                sorgis_raid_marks.position = {gui.getPosition()} 
            end
        end
        gui.toggleShowCasts = function()
            sorgis_raid_marks.show_casts = not sorgis_raid_marks.show_casts
        end
        gui.getShowCasts = function()
            return sorgis_raid_marks.show_casts
        end
        gui.togglePlayerCasts = function()
            sorgis_raid_marks.player_casts = not sorgis_raid_marks.player_casts
        end
        gui.getPlayerCasts = function()
            return sorgis_raid_marks.player_casts
        end
        gui.setfadeunmarked = function(aAlpha)
            sorgis_raid_marks.fadeunmarked = (aAlpha > 0 and aAlpha <= 100 and aAlpha) or 100
        end
        gui.getfadeunmarked = function()
            return sorgis_raid_marks.fadeunmarked
        end
        gui.getvertical = function()
            return sorgis_raid_marks.vertical
        end
        gui.togglevertical = function(vert)
            sorgis_raid_marks.vertical = not sorgis_raid_marks.vertical
        end
        gui.getreverse = function()
            return sorgis_raid_marks.reverse
        end
        gui.togglereverse = function(rev)
            sorgis_raid_marks.reverse = not sorgis_raid_marks.reverse
        end
        gui.reset = function()
            gui.setMovable(true)
            gui.setVisibility(true)
            gui.setScale(32)
       
            w = rootFrame:GetParent():GetWidth()
            h = rootFrame:GetParent():GetHeight()
            gui.setPosition(w/2,h/2*-1)
        end
        gui.orientMarks = function()
            for i,button in ipairs(trayButtons) do
                button.setPosition(
                    sorgis_raid_marks.vertical and 0 or (sorgis_raid_marks.reverse and 8-i or i-1),
                    sorgis_raid_marks.vertical and (sorgis_raid_marks.reverse and 8-i or i-1) or 0
                )
            end
        end

        rootFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        if has_superwow then
            rootFrame:RegisterEvent("UNIT_CASTEVENT")
            rootFrame:RegisterEvent("RAID_TARGET_UPDATE")
        end

        local tracked_marks = {}
        local trackMarks = function()
            local t = {}
            for i=1,8 do
                local mark = "mark"..i
                local _,guid = UnitExists(mark)
                if guid then
                    t[guid] = true
                    trayButtons[i].guid = guid
                else
                    trayButtons[i].guid = nil
                end
            end
            tracked_marks = t
        end

        rootFrame:SetScript("OnEvent", function()
            if event == "PLAYER_ENTERING_WORLD" then
                sorgis_raid_marks = sorgis_raid_marks or {}
                sorgis_raid_marks.position = sorgis_raid_marks.position or {}
                sorgis_raid_marks.show_casts = sorgis_raid_marks.show_casts or true
                sorgis_raid_marks.player_casts = sorgis_raid_marks.player_casts or false
                sorgis_raid_marks.fadeunmarked = sorgis_raid_marks.fadeunmarked or 40
                sorgis_raid_marks.vertical = sorgis_raid_marks.vertical or false
                sorgis_raid_marks.reverse = sorgis_raid_marks.reverse or false

                gui.setScale(sorgis_raid_marks.scale or 32)
                gui.setVisibility(sorgis_raid_marks.visibility == nil or sorgis_raid_marks.visibility)
                gui.setMovable(sorgis_raid_marks.locked ~= true)

                if type(sorgis_raid_marks.position[1]) == "number" then
                    gui.setPosition(unpack(sorgis_raid_marks.position))
                else
                    w = rootFrame:GetParent():GetWidth()
                    h = rootFrame:GetParent():GetHeight()
                    gui.setPosition(w/2,h/2*-1)
                end

                gui.orientMarks()

                if has_superwow then trackMarks() end
            elseif has_superwow and event == "RAID_TARGET_UPDATE" then
                trackMarks()
            elseif has_superwow and gui.getShowCasts() and event == "UNIT_CASTEVENT" then
                if (gui.getPlayerCasts() or not UnitIsPlayer(arg1))then
                    if tracked_marks[arg1] then
                        if arg3 == "START" then
                            local _,_,t = SpellInfo(arg4)
                            cast_log[arg1] = { start = GetTime(), duration = arg5 / 1000, texture = t }
                        elseif arg3 == "FAIL" or arg3 == "CAST" then
                            cast_log[arg1] = nil
                        end
                    end
                end
            end
        end)

        return gui
    end)();

    ---------------------------
    -- target tray settings CLI
    ---------------------------
    local commands = {
        ["lock"] = {
            "prevent the tray from being dragged by the mouse",
            function()
                gui.lock()
                srm.log("tray locked")
            end
        },
        ["unlock"] = {
            "allows the tray to be dragged by the mouse",
            function()
                gui.unlock()
                srm.log("tray unlocked")
            end
        },
        ["hide"] = {
            "hides the tray",
            function()
                gui.setVisibility(false)
                srm.log("tray hidden")
            end
        },
        ["show"] = {
            "shows the tray",
            function()
                gui.setVisibility(true)
                srm.log("tray shown")
            end
        },
        ["reset"] = {
            "moves tray to center of the screen, resets all settings",
            function()
                gui.reset()
            end
        },
        ["scale"] = {
            "resize the tray if given a number. Prints the current scale value if no number provided",
            function(aScale)
                if aScale then
                    gui.setScale(tonumber(aScale)) 
                end

                srm.log("scale is: ", gui.getScale())
            end
        },
        ["casts"] = {
            "toggles showing casts on mark icons",
            function()
                gui.toggleShowCasts()
                srm.log("showing casts is: ", gui.getShowCasts() and "on" or "off")
            end
        },
        ["playercasts"] = {
            "toggles show casts from marked players",
            function()
                gui.togglePlayerCasts()
                srm.log("showing player casts is: ", gui.getPlayerCasts() and "on" or "off")
            end
        },
        ["fadeunmarked"] = {
            "fade unset marks, alpha range 0-100",
            function(aAlpha)
                if aAlpha then
                    gui.setfadeunmarked(tonumber(aAlpha))
                end
                srm.log("visibility is: ", gui.getfadeunmarked(), "%")
            end
        },
        ["vertical"] = {
            "make marks vertically oriented",
            function()
                gui.togglevertical()
                gui.orientMarks()
                srm.log("mark orientation is: ", gui.getvertical() and "vertical" or "horizontal")
            end
        },
        ["reverse"] = {
            "reverse mark display order",
            function()
                gui.togglereverse()
                gui.orientMarks()
                srm.log("mark display order is: ", gui.getreverse() and "skull..star" or "star..skull")
            end
        },
    }
     
    srm.makeSlashCommand("sraidmarks", function(msg)
        local arg = {}
        
        for word in string.gfind(msg, "\(%w+\)") do
            table.insert(arg, word)
        end

        local commandName = table.remove(arg, 1);

        (commands[commandName] and commands[commandName][2] or function()
            local commandsString = ""
            for command, value in pairs(commands) do
                commandsString = "`" .. _G.SLASH_SRAIDMARKS1 .. " " .. command ..
                "` : " .. value[1]
                srm.log(commandsString)
            end 
        end)(unpack(arg))
    end)
end

