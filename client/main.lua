-- ============================================================
--  CARRO FORTE — CLIENT/MAIN.LUA
--  Lógica principal do cliente: zona de início, missão,
--  veículo, coleta, entrega, velocidade e assaltos.
-- ============================================================

local vrp       = exports["vrp"]:getSharedObject()
local vrpClient = exports["vrp_client"]:getSharedObject()

-- ============================================================
--  ESTADO LOCAL
-- ============================================================

local isOnJob        = false
local currentMission = nil   -- dados da missão atual
local currentVehicle = nil   -- entidade do veículo
local speedWarned    = false  -- se o aviso de velocidade foi dado
local penaltyCount   = 0      -- quantas violações de velocidade

local blips = {}   -- blips criados durante a missão
local peds  = {}   -- NPCs de assalto criados

-- Blip permanente do local de início (criado uma vez ao carregar)
local jobBlip = nil

-- ============================================================
--  UTILITÁRIOS
-- ============================================================

local function clearBlips()
    for _, b in ipairs(blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    blips = {}
end

local function clearPeds()
    for _, p in ipairs(peds) do
        if DoesEntityExist(p) then DeleteEntity(p) end
    end
    peds = {}
end

local function addBlip(x, y, z, sprite, color, scale, label, route)
    local b = AddBlipForCoord(x, y, z)
    SetBlipSprite(b, sprite)
    SetBlipColor(b, color)
    SetBlipScale(b, scale)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(b)
    if route then
        SetBlipRoute(b, true)
        SetBlipRouteColour(b, color)
    end
    table.insert(blips, b)
    return b
end

local function isNear(point, dist)
    local p = GetEntityCoords(PlayerPedId())
    return #(p - vector3(point.x, point.y, point.z)) <= (dist or Config.InteractionDistance)
end

local function calcEarnings()
    if not currentMission then return 0, 0 end
    local base    = Config.PayPerDelivery * currentMission.total
    local raw     = penaltyCount * Config.SpeedPenalty
    local capped  = math.min(raw, Config.MaxSpeedPenalty)
    local penalty = math.floor(base * capped)
    return math.max(base - penalty, 0), penalty
end

-- Redesenha todos os blips da missão
local function refreshBlips()
    clearBlips()
    if not currentMission then return end

    local firstUncollected = true
    for _, pickup in ipairs(currentMission.pickups) do
        if not pickup.collected then
            local b = addBlip(
                pickup.x, pickup.y, pickup.z,
                Config.PickupBlip.sprite,
                Config.PickupBlip.color,
                Config.PickupBlip.scale,
                pickup.label,
                firstUncollected   -- rota ativa só no primeiro
            )
            firstUncollected = false
        end
    end

    -- Blip da entrega: rota ativa só quando tudo foi coletado
    local allDone = (currentMission.collected >= currentMission.total)
    addBlip(
        currentMission.delivery.x,
        currentMission.delivery.y,
        currentMission.delivery.z,
        Config.DeliveryBlip.sprite,
        Config.DeliveryBlip.color,
        Config.DeliveryBlip.scale,
        currentMission.delivery.label,
        allDone
    )
end

-- ============================================================
--  BLIP PERMANENTE DO LOCAL DE INÍCIO
--  Aparece no mapa assim que o recurso carrega.
-- ============================================================

Citizen.CreateThread(function()
    local loc = Config.JobLocation

    jobBlip = AddBlipForCoord(loc.x, loc.y, loc.z)
    SetBlipSprite(jobBlip, loc.blipSprite)
    SetBlipColor(jobBlip, loc.blipColor)
    SetBlipScale(jobBlip, loc.blipScale)
    SetBlipAsShortRange(jobBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(loc.blipLabel)
    EndTextCommandSetBlipName(jobBlip)
end)

-- ============================================================
--  THREAD DE ZONA DE INÍCIO
--  Detecta quando o jogador chega ao local e mostra "Aperte E"
-- ============================================================

Citizen.CreateThread(function()
    local loc  = Config.JobLocation
    local dist = loc.interactDistance or 3.5

    while true do
        -- Quando longe do local, dorme mais para economizar CPU
        local playerCoords = GetEntityCoords(PlayerPedId())
        local distToLoc    = #(playerCoords - vector3(loc.x, loc.y, loc.z))

        if distToLoc > 50.0 then
            Citizen.Wait(1500)
        elseif distToLoc > dist then
            Citizen.Wait(500)
        else
            -- Jogador está na zona de interação
            Citizen.Wait(0)

            DrawText3D(loc.x, loc.y, loc.z + 1.0, loc.interactText)

            if IsControlJustReleased(0, 38) then  -- tecla E
                if not isOnJob then
                    TriggerServerEvent("carro_forte:requestJob")
                else
                    CF_Toast("warning", "⚠️", "Você já está em missão!", "Conclua ou cancele a missão atual.")
                end
            end
        end
    end
end)

-- ============================================================
--  INICIAR MISSÃO  (recebido do servidor após aceitar)
-- ============================================================

RegisterNetEvent("carro_forte:startMission")
AddEventHandler("carro_forte:startMission", function(missionData)
    isOnJob        = true
    currentMission = missionData
    penaltyCount   = 0
    speedWarned    = false

    refreshBlips()

    -- Abre a tela de pegar o caminhão
    TriggerEvent("carro_forte:showTruckScreen")
end)

-- ============================================================
--  SPAWNAR VEÍCULO  (disparado após clicar em "Pegar Caminhão")
-- ============================================================

RegisterNetEvent("carro_forte:spawnVehicle")
AddEventHandler("carro_forte:spawnVehicle", function()
    local sp    = Config.SpawnPoint
    local model = GetHashKey(Config.Vehicle)

    RequestModel(model)
    while not HasModelLoaded(model) do Citizen.Wait(100) end

    local veh = CreateVehicle(model, sp.x, sp.y, sp.z, sp.heading, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleDoorsLocked(veh, 10)
    SetVehicleNumberPlateText(veh, Config.VehiclePlate)
    SetVehicleEngineOn(veh, true, true)
    SetVehicleModKit(veh, 0)
    SetModelAsNoLongerNeeded(model)

    currentVehicle = veh

    -- Coloca o jogador no banco do motorista
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    SetVehicleDoorsLocked(veh, 1)

    -- Inicializa o HUD
    local earnings, penalty = calcEarnings()
    CF_ShowHUD(0, currentMission.total, earnings, Config.BonusComplete, penalty)

    CF_Toast("info", "🚛", "Carro Forte pronto!", "Siga os blips azuis nos bancos e aperte E para coletar.")
end)

-- ============================================================
--  ENCERRAR MISSÃO
-- ============================================================

RegisterNetEvent("carro_forte:endMission")
AddEventHandler("carro_forte:endMission", function(reason)
    isOnJob        = false
    currentMission = nil
    penaltyCount   = 0
    speedWarned    = false

    clearBlips()
    clearPeds()
    CF_HideHUD()

    if currentVehicle and DoesEntityExist(currentVehicle) then
        SetEntityAsMissionEntity(currentVehicle, false, true)
        DeleteEntity(currentVehicle)
        currentVehicle = nil
    end

    if reason == "failed" then
        CF_Toast("danger",  "💥", "Missão perdida!",   "O carro forte foi destruído.")
    elseif reason == "quit" then
        CF_Toast("warning", "❌", "Missão cancelada.", "Você abandonou o trabalho.")
    elseif reason == "complete" then
        CF_Toast("success", "🎉", "Missão concluída!", "Confira o pagamento recebido.")
    end
end)

-- ============================================================
--  COLETA ATUALIZADA  (retorno do servidor)
-- ============================================================

RegisterNetEvent("carro_forte:updatePickup")
AddEventHandler("carro_forte:updatePickup", function(collected, total)
    if currentMission then
        currentMission.collected = collected
    end
    refreshBlips()

    local earnings, penalty = calcEarnings()
    CF_UpdateHUD(collected, total, earnings, Config.BonusComplete, penalty, false)

    if collected >= total then
        CF_Toast("success", "🏦", "Todos os bancos coletados!", "Leve o dinheiro à Reserva Federal!")
    else
        local restante = total - collected
        CF_Toast("info", "📦", "Caixa coletada!", restante .. " banco(s) restante(s).")
    end
end)

-- ============================================================
--  PAGAMENTO RECEBIDO
-- ============================================================

RegisterNetEvent("carro_forte:paymentReceived")
AddEventHandler("carro_forte:paymentReceived", function(amount, bonus)
    CF_Toast("gold", "💰", "Pagamento recebido!", "Entrega: $" .. amount)

    if bonus and bonus > 0 then
        Citizen.SetTimeout(2000, function()
            CF_Toast("gold", "⭐", "Bônus de missão!", "+$" .. bonus)
        end)
    end
end)

-- ============================================================
--  ASSALTO AO CARRO FORTE
-- ============================================================

RegisterNetEvent("carro_forte:robbery")
AddEventHandler("carro_forte:robbery", function(coords)
    CF_Toast("danger", "🚨", "ASSALTO!", "Criminosos estão atacando o carro forte!")

    local pedModel = GetHashKey(Config.RobberyPedModel)
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Citizen.Wait(100) end

    for i = 1, Config.RobberyPedCount do
        local ox  = math.random(-6, 6)
        local oy  = math.random(-6, 6)
        local ped = CreatePed(4, pedModel,
            coords.x + ox, coords.y + oy, coords.z,
            math.random(0, 360), true, false)

        SetPedAsCop(ped, false)
        SetPedRelationshipGroupHash(ped, GetHashKey("HATES_PLAYER"))
        GiveWeaponToPed(ped, GetHashKey(Config.RobberyWeapon), 150, false, true)
        SetPedCombatAttributes(ped, 46, true)
        TaskCombatPed(ped, PlayerPedId(), 0, 16)

        table.insert(peds, ped)
    end

    SetModelAsNoLongerNeeded(pedModel)
end)

-- ============================================================
--  THREAD PRINCIPAL — Interação com bancos e entrega
-- ============================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)

        if isOnJob and currentMission then

            -- Interação com cada banco não coletado
            for i, pickup in ipairs(currentMission.pickups) do
                if not pickup.collected and isNear(pickup) then
                    DrawText3D(pickup.x, pickup.y, pickup.z + 1.2,
                        "Pressione ~g~E~w~ para coletar o dinheiro")

                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent("carro_forte:collectMoney", i)
                        pickup.collected = true   -- otimista; o servidor confirma
                    end
                end
            end

            -- Interação com ponto de entrega (só quando tudo coletado)
            local allDone  = (currentMission.collected >= currentMission.total)
            local delivery = currentMission.delivery

            if allDone and isNear(delivery) then
                DrawText3D(delivery.x, delivery.y, delivery.z + 1.2,
                    "Pressione ~g~E~w~ para entregar o dinheiro")

                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent("carro_forte:deliverMoney")
                end
            end
        end
    end
end)

-- ============================================================
--  THREAD DE VELOCIDADE — Monitoramento e penalidades
-- ============================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)

        if isOnJob and currentVehicle and DoesEntityExist(currentVehicle) then
            local ped = PlayerPedId()

            if IsPedInVehicle(ped, currentVehicle, false) then
                local speed = GetEntitySpeed(currentVehicle) * 3.6   -- m/s → km/h

                if speed > Config.SpeedLimit then
                    if not speedWarned then
                        speedWarned  = true
                        penaltyCount = penaltyCount + 1
                        TriggerServerEvent("carro_forte:speedViolation")
                        CF_Toast("warning", "⚡", "Velocidade alta!", "Penalidade aplicada. Reduza para " .. Config.SpeedLimit .. " km/h.")
                    end
                    local earnings, penalty = calcEarnings()
                    CF_UpdateHUD(currentMission.collected, currentMission.total,
                        earnings, Config.BonusComplete, penalty, true)
                else
                    if speedWarned then
                        speedWarned = false
                        local earnings, penalty = calcEarnings()
                        CF_UpdateHUD(currentMission.collected, currentMission.total,
                            earnings, Config.BonusComplete, penalty, false)
                    end
                end

                -- Veículo destruído = missão falhou
                if IsEntityDead(currentVehicle) or GetEntityHealth(currentVehicle) < 200 then
                    TriggerServerEvent("carro_forte:vehicleDestroyed")
                end
            end
        end
    end
end)

-- ============================================================
--  AUXILIAR: Texto 3D no mundo
-- ============================================================

function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    local px, py, pz       = table.unpack(GetGameplayCamCoord())
    local dist  = #(vector3(px, py, pz) - vector3(x, y, z))
    local scale = (1 / dist) * 2
    local fov   = (1 / GetGameplayCamFov()) * 100

    if onScreen then
        SetTextScale(0.0 * scale * fov, 0.55 * scale * fov)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(sx, sy)
    end
end
