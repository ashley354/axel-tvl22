local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local ESP_CACHE = {}
local ESP_ENABLED = false
local STEALTH_MODE = true
local TELEPORT_DELAY = 0.45
local MOVEMENT_SMOOTH = true
local teleportInputValue = ""

local HITBOX_ENABLED = false
local HITBOX_SIZE = 2.5
local HITBOX_ORIGINAL_SIZES = {}
local HITBOX_MONITOR
local LAST_HITBOX_CHANGE = 0
local HITBOX_COOLDOWN = 0.5
local SELECTED_PLAYERS = {}

-- Anti-detecção
local ANTI_DETECTION_ENABLED = true
local TELEPORT_COUNT = 0
local LAST_TELEPORT = 0
local MAX_TELEPORTS_PER_MINUTE = 15
local TELEPORT_REST_TIME = 0

local Window = Rayfield:CreateWindow({
   Name = "🎮 AXEL TVL - Vampire Legends",
   Icon = 0,
   LoadingTitle = "Rayfield Interface Suite",
   LoadingSubtitle = "by Sirius",
   ShowText = "Rayfield",
   Theme = "Default",

   ToggleUIKeybind = "K",

   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false,

   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil,
      FileName = "AXEL TVL - Vampire Legends"
   },

   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },

   KeySystem = false,
})

local MainTab = Window:CreateTab("Inicio", nil)
local HitboxTab = Window:CreateTab("Hitbox", nil)
local SelectPlayerTab = Window:CreateTab("Selecionar Players", nil)
local AntiDetectTab = Window:CreateTab("Anti-Deteccao", nil)

local function findPlayerByPartialName(partialName)
    if not partialName or partialName == "" then return nil end
    partialName = tostring(partialName):lower():match("^%s*(.-)%s*$")

    if not partialName or partialName == "" then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower():find(partialName, 1, true) then
            return player
        end
    end

    return nil
end

local function removeESP(player)
    if ESP_CACHE[player] then
        pcall(function()
            ESP_CACHE[player]:Destroy()
        end)
        ESP_CACHE[player] = nil
    end
end

local function createESP(player)
    removeESP(player)

    if player == LocalPlayer then return end

    pcall(function()
        local character = player.Character
        if not character then return end

        local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        if not head then return end

        local bill = Instance.new("BillboardGui")
        bill.Name = "ESP_" .. player.Name
        bill.Parent = CoreGui
        bill.Adornee = head
        bill.Size = UDim2.new(0, 200, 0, 40)
        bill.StudsOffset = Vector3.new(0, 3, 0)
        bill.AlwaysOnTop = true
        bill.MaxDistance = 500

        local lbl = Instance.new("TextLabel", bill)
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = player.Name
        lbl.TextColor3 = Color3.new(1, 0, 0)
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13
        lbl.TextStrokeTransparency = 0.3

        ESP_CACHE[player] = bill
    end)
end

local function setupPlayer(player)
    pcall(function()
        player.CharacterAdded:Connect(function(char)
            if ESP_ENABLED then
                wait(0.1)
                createESP(player)
            end
        end)

        if player.Character and ESP_ENABLED then
            createESP(player)
        end
    end)
end

local function enableESPAll()
    for _, player in ipairs(Players:GetPlayers()) do
        if not ESP_CACHE[player] then
            createESP(player)
        end
    end
end

local function disableESPAll()
    for player, _ in pairs(ESP_CACHE) do
        removeESP(player)
    end
end

local function teleportToPlayerStealth(playerName)
    if TELEPORT_REST_TIME > 0 then
        Rayfield:Notify({
            Title = "Espera",
            Content = "Teleporte em cooldown: " .. math.ceil(TELEPORT_REST_TIME) .. "s",
            Duration = 2,
        })
        return
    end

    local targetPlayer = findPlayerByPartialName(playerName)

    if not targetPlayer then
        Rayfield:Notify({
            Title = "Erro",
            Content = "Player nao encontrado",
            Duration = 1,
        })
        return
    end

    pcall(function()
        if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            Rayfield:Notify({
                Title = "Erro",
                Content = "Sem personagem",
                Duration = 1,
            })
            return
        end

        local myChar = LocalPlayer.Character
        if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end

        local targetPos = targetPlayer.Character.HumanoidRootPart.CFrame
        local myPos = myChar.HumanoidRootPart.CFrame

        local randomDelay = math.random(5, 20) / 100
        wait(randomDelay)

        local distance = (targetPos.Position - myPos.Position).Magnitude
        local steps = math.max(8, math.ceil(distance / 6))
        local stepDelay = TELEPORT_DELAY / steps

        for i = 1, steps do
            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then break end

            local progress = i / steps
            local newCFrame = myPos:Lerp(targetPos, progress)
            LocalPlayer.Character.HumanoidRootPart.CFrame = newCFrame

            wait(stepDelay)
        end

        TELEPORT_COUNT = TELEPORT_COUNT + 1
        LAST_TELEPORT = tick()

        Rayfield:Notify({
            Title = "OK",
            Content = "Teleportado (" .. TELEPORT_COUNT .. "/15)",
            Duration = 1,
        })
    end)
end

local function storeOriginalSizes(player)
    pcall(function()
        if not player.Character then return end

        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") and not HITBOX_ORIGINAL_SIZES[part] then
                local parent = part.Parent
                if not parent:IsA("Accessory") and not parent:IsA("CharacterMesh") then
                    HITBOX_ORIGINAL_SIZES[part] = {
                        Size = part.Size,
                        CanCollide = part.CanCollide,
                        Massless = part.Massless
                    }
                end
            end
        end
    end)
end

local function expandHitbox(player)
    pcall(function()
        if not player.Character then return end
        if player == LocalPlayer then return end

        storeOriginalSizes(player)

        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") and HITBOX_ORIGINAL_SIZES[part] then
                local originalSize = HITBOX_ORIGINAL_SIZES[part].Size
                part.Size = originalSize * HITBOX_SIZE
                part.CanCollide = false
                part.Massless = true
            end
        end
    end)
end

local function resetHitbox(player)
    pcall(function()
        if not player.Character then return end

        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") and HITBOX_ORIGINAL_SIZES[part] then
                part.Size = HITBOX_ORIGINAL_SIZES[part].Size
                part.CanCollide = HITBOX_ORIGINAL_SIZES[part].CanCollide
                part.Massless = HITBOX_ORIGINAL_SIZES[part].Massless
                HITBOX_ORIGINAL_SIZES[part] = nil
            end
        end
    end)
end

local function startHitboxMonitoring()
    if HITBOX_MONITOR then HITBOX_MONITOR:Disconnect() end

    HITBOX_MONITOR = RunService.Heartbeat:Connect(function()
        if not HITBOX_ENABLED then return end

        local now = tick()
        if now - LAST_HITBOX_CHANGE < HITBOX_COOLDOWN then return end
        LAST_HITBOX_CHANGE = now

        for _, player in ipairs(SELECTED_PLAYERS) do
            if player and player.Character then
                pcall(function()
                    for _, part in ipairs(player.Character:GetDescendants()) do
                        if part:IsA("BasePart") and HITBOX_ORIGINAL_SIZES[part] then
                            local targetSize = HITBOX_ORIGINAL_SIZES[part].Size * HITBOX_SIZE
                            if (part.Size - targetSize).Magnitude > 0.1 then
                                part.Size = targetSize
                            end
                        end
                    end
                end)
            end
        end
    end)
end

local function stopHitboxMonitoring()
    if HITBOX_MONITOR then
        HITBOX_MONITOR:Disconnect()
        HITBOX_MONITOR = nil
    end
end

local function enableHitbox()
    HITBOX_ENABLED = true
    startHitboxMonitoring()

    for _, player in ipairs(SELECTED_PLAYERS) do
        if player then
            storeOriginalSizes(player)
            expandHitbox(player)
        end
    end
end

local function disableHitbox()
    HITBOX_ENABLED = false
    stopHitboxMonitoring()

    for _, player in ipairs(SELECTED_PLAYERS) do
        if player then
            resetHitbox(player)
        end
    end

    for part, _ in pairs(HITBOX_ORIGINAL_SIZES) do
        pcall(function()
            if part and part.Parent then
                part.Size = HITBOX_ORIGINAL_SIZES[part].Size
                part.CanCollide = HITBOX_ORIGINAL_SIZES[part].CanCollide
                part.Massless = HITBOX_ORIGINAL_SIZES[part].Massless
            end
        end)
    end
    HITBOX_ORIGINAL_SIZES = {}
end

local antiDetectConnection
local function startAntiDetect()
    if antiDetectConnection then antiDetectConnection:Disconnect() end

    antiDetectConnection = RunService.Heartbeat:Connect(function()
        if not ANTI_DETECTION_ENABLED then return end

        local now = tick()
        local timeSinceLastTP = now - LAST_TELEPORT

        if timeSinceLastTP > 60 then
            TELEPORT_COUNT = 0
        end

        if TELEPORT_COUNT >= MAX_TELEPORTS_PER_MINUTE then
            TELEPORT_REST_TIME = 30
        end

        if TELEPORT_REST_TIME > 0 then
            TELEPORT_REST_TIME = TELEPORT_REST_TIME - (1/60)
        end
    end)
end

local function stopAntiDetect()
    if antiDetectConnection then
        antiDetectConnection:Disconnect()
        antiDetectConnection = nil
    end
end

-- ===== MAIN TAB =====
MainTab:CreateToggle({
    Name = "Mostrar Nomes (ESP)",
    CurrentValue = false,
    Flag = "Toggle_ESP",
    Callback = function(Value)
        ESP_ENABLED = Value
        if Value then
            enableESPAll()
        else
            disableESPAll()
        end
    end,
})

MainTab:CreateDivider()

local teleportInput = MainTab:CreateInput({
    Name = "Nome do Player",
    PlaceholderText = "Digite o nome",
    RemoveTextAfterFocusLost = false,
    Flag = "TeleportInput",
    Callback = function(Text)
        teleportInputValue = tostring(Text):match("^%s*(.-)%s*$") or ""
    end,
})

MainTab:CreateButton({
    Name = "Teleportar",
    Callback = function()
        if teleportInputValue and teleportInputValue ~= "" then
            teleportToPlayerStealth(teleportInputValue)
        else
            Rayfield:Notify({
                Title = "Erro",
                Content = "Digite um nome",
                Duration = 1,
            })
        end
    end,
})

MainTab:CreateDivider()

MainTab:CreateToggle({
    Name = "Velocidade Normal",
    CurrentValue = true,
    Flag = "StealthMode",
    Callback = function(Value)
        if Value then
            TELEPORT_DELAY = 0.45
        else
            TELEPORT_DELAY = 0.2
        end
    end,
})

MainTab:CreateSlider({
    Name = "Velocidade Teleporte",
    Range = {0.1, 1},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.45,
    Flag = "TeleportSpeed",
    Callback = function(Value)
        TELEPORT_DELAY = Value
    end,
})

-- ===== HITBOX TAB =====
HitboxTab:CreateToggle({
    Name = "Hitbox Expander (Selecionados)",
    CurrentValue = false,
    Flag = "HitboxExpander",
    Callback = function(Value)
        if Value then
            if #SELECTED_PLAYERS == 0 then
                Rayfield:Notify({
                    Title = "Erro",
                    Content = "Selecione players primeiro!",
                    Duration = 2,
                })
                return
            end
            enableHitbox()
            Rayfield:Notify({
                Title = "Hitbox",
                Content = "Expandido em " .. #SELECTED_PLAYERS .. " players",
                Duration = 1,
            })
        else
            disableHitbox()
            Rayfield:Notify({
                Title = "Hitbox",
                Content = "Desativado",
                Duration = 1,
            })
        end
    end,
})

HitboxTab:CreateDivider()

HitboxTab:CreateSlider({
    Name = "Tamanho Hitbox",
    Range = {1, 5},
    Increment = 0.5,
    Suffix = "x",
    CurrentValue = 2.5,
    Flag = "HitboxSize",
    Callback = function(Value)
        HITBOX_SIZE = Value
        if HITBOX_ENABLED then
            disableHitbox()
            wait(0.1)
            enableHitbox()
        end
    end,
})

HitboxTab:CreateLabel("🎯 Selecionados: " .. #SELECTED_PLAYERS)
HitboxTab:CreateLabel("Vai até 'Selecionar Players'")

-- ===== SELECIONAR PLAYERS TAB =====
SelectPlayerTab:CreateLabel("🎯 CLIQUE NOS PLAYERS:")
SelectPlayerTab:CreateDivider()

local playerButtons = {}

local function updatePlayerList()
    local players = Players:GetPlayers()

    for _, player in ipairs(players) do
        if player ~= LocalPlayer then
            if not playerButtons[player.Name] then
                local text = player.Name

                playerButtons[player.Name] = SelectPlayerTab:CreateButton({
                    Name = text,
                    Callback = function()
                        local idx = table.find(SELECTED_PLAYERS, player)
                        if idx then
                            table.remove(SELECTED_PLAYERS, idx)
                            if HITBOX_ENABLED then
                                resetHitbox(player)
                            end
                        else
                            table.insert(SELECTED_PLAYERS, player)
                            if HITBOX_ENABLED then
                                storeOriginalSizes(player)
                                expandHitbox(player)
                            end
                        end
                    end,
                })
            end
        end
    end
end

SelectPlayerTab:CreateDivider()

SelectPlayerTab:CreateButton({
    Name = "✅ Selecionar Todos",
    Callback = function()
        SELECTED_PLAYERS = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(SELECTED_PLAYERS, player)
                if HITBOX_ENABLED then
                    storeOriginalSizes(player)
                    expandHitbox(player)
                end
            end
        end

        Rayfield:Notify({
            Title = "Selecionado",
            Content = #SELECTED_PLAYERS .. " players",
            Duration = 1,
        })
    end,
})

SelectPlayerTab:CreateButton({
    Name = "✅ Selecionar Todos + Ativar",
    Callback = function()
        SELECTED_PLAYERS = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(SELECTED_PLAYERS, player)
            end
        end

        if #SELECTED_PLAYERS > 0 then
            enableHitbox()
            Rayfield:Notify({
                Title = "Ativado",
                Content = "Hitbox em " .. #SELECTED_PLAYERS .. " players",
                Duration = 1,
            })
        end
    end,
})

SelectPlayerTab:CreateButton({
    Name = "🔄 Atualizar Lista",
    Callback = function()
        updatePlayerList()
        Rayfield:Notify({
            Title = "Atualizado",
            Content = "Selecionados: " .. #SELECTED_PLAYERS,
            Duration = 1,
        })
    end,
})

SelectPlayerTab:CreateButton({
    Name = "🗑️ Limpar Seleção",
    Callback = function()
        if HITBOX_ENABLED then
            disableHitbox()
        end

        SELECTED_PLAYERS = {}

        for part, _ in pairs(HITBOX_ORIGINAL_SIZES) do
            pcall(function()
                if part and part.Parent then
                    part.Size = HITBOX_ORIGINAL_SIZES[part].Size
                    part.CanCollide = HITBOX_ORIGINAL_SIZES[part].CanCollide
                    part.Massless = HITBOX_ORIGINAL_SIZES[part].Massless
                end
            end)
        end
        HITBOX_ORIGINAL_SIZES = {}

        Rayfield:Notify({
            Title = "Limpo",
            Content = "Todos deselecionados",
            Duration = 1,
        })
    end,
})

wait(1)
updatePlayerList()

Players.PlayerAdded:Connect(function(player)
    setupPlayer(player)
    wait(0.5)
    updatePlayerList()
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)

    if HITBOX_ENABLED then
        resetHitbox(player)
    end

    local idx = table.find(SELECTED_PLAYERS, player)
    if idx then
        table.remove(SELECTED_PLAYERS, idx)
    end
end)

-- ===== ANTI-DETECÇÃO TAB =====
AntiDetectTab:CreateToggle({
    Name = "Anti-Deteccao Ativada",
    CurrentValue = true,
    Flag = "AntiDetect",
    Callback = function(Value)
        ANTI_DETECTION_ENABLED = Value
        if Value then
            startAntiDetect()
        else
            stopAntiDetect()
        end
    end,
})

AntiDetectTab:CreateDivider()

AntiDetectTab:CreateSlider({
    Name = "Max Teleportes/Min",
    Range = {5, 30},
    Increment = 1,
    Suffix = "tp",
    CurrentValue = 15,
    Flag = "MaxTeleports",
    Callback = function(Value)
        MAX_TELEPORTS_PER_MINUTE = Value
    end,
})

AntiDetectTab:CreateLabel("Padrão: 15 teleportes/minuto")
AntiDetectTab:CreateLabel("Cooldown: 30s")

-- ===== CONECTAR EVENTOS =====
for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

startAntiDetect()

Rayfield:Notify({
    Title = "🎮 AXEL TVL",
    Content = "Vampire Legends - Ready!",
    Duration = 2,
})
