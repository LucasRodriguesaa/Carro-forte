-- ============================================================
--  CARRO FORTE — SERVER/MAIN.LUA
--  Gerencia missões, pagamentos e segurança server-side.
-- ============================================================

local vrp = exports["vrp"]:getSharedObject()

-- ============================================================
--  ESTADO DAS MISSÕES ATIVAS
--  activeMissions[source] = {
--    pickups        = { {x,y,z,label,collected=bool}, ... },
--    delivery       = { x,y,z,label },
--    collected      = 0,
--    total          = N,
--    speedViolations = 0,
--  }
-- ============================================================

local activeMissions = {}

-- ============================================================
--  UTILITÁRIOS
-- ============================================================

local function getUserId(source)
    return vrp.getUserId(source)
end

local function giveMoney(source, amount)
    local uid = getUserId(source)
    if not uid then return end

    if Config.MoneyType == "dirty_money" then
        vrp.giveInventoryItem(uid, "dirty_money", amount)
    else
        vrp.giveMoney(uid, amount)
    end
end

local function chatMsg(source, msg)
    TriggerClientEvent("chatMessage", source, "", {0, 150, 255}, "[CARRO FORTE] " .. msg)
end

local function shuffleTable(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function selectPickups(count)
    local pool = {}
    for _, loc in ipairs(Config.PickupLocations) do
        table.insert(pool, { x = loc.x, y = loc.y, z = loc.z, label = loc.label, collected = false })
    end
    pool = shuffleTable(pool)

    local selected = {}
    for i = 1, math.min(count, #pool) do
        table.insert(selected, pool[i])
    end
    return selected
end

-- ============================================================
--  SOLICITAR JOB
--  Disparado pelo cliente quando o jogador pressiona E no
--  local de início. Verifica condições e abre o despachante.
-- ============================================================

RegisterServerEvent("carro_forte:requestJob")
AddEventHandler("carro_forte:requestJob", function()
    local source = source
    local uid    = getUserId(source)
    if not uid then return end

    -- Verificar proximidade do local de início (anti-cheat)
    local ped    = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local loc    = Config.JobLocation
    local dist   = #(coords - vector3(loc.x, loc.y, loc.z))

    if dist > 15.0 then
        chatMsg(source, "Você precisa estar no local de contratação.")
        return
    end

    -- Verificar se já está em missão
    if activeMissions[source] then
        chatMsg(source, "Você já está em uma missão de carro forte!")
        return
    end

    -- Verificar grupo/job (se Config.RequireJob = true)
    if Config.RequireJob then
        local groups = vrp.getUserGroups(uid)
        if not groups[Config.JobName] then
            chatMsg(source, "Você não tem o emprego de " .. Config.JobLabel .. ".")
            return
        end
    end

    -- Tudo ok → abre o menu do despachante no cliente
    TriggerClientEvent("carro_forte:showDispatcherMenu", source)
end)

-- ============================================================
--  ACEITAR JOB  (clicou em "Aceitar Missão" na NUI)
-- ============================================================

RegisterServerEvent("carro_forte:acceptJob")
AddEventHandler("carro_forte:acceptJob", function()
    local source = source
    local uid    = getUserId(source)
    if not uid then return end

    if activeMissions[source] then
        chatMsg(source, "Você já está em uma missão.")
        return
    end

    local numDeliveries = math.random(Config.MinDeliveries, Config.MaxDeliveries)
    local pickups       = selectPickups(numDeliveries)

    activeMissions[source] = {
        pickups         = pickups,
        delivery        = Config.DeliveryLocation,
        collected       = 0,
        total           = numDeliveries,
        speedViolations = 0,
    }

    TriggerClientEvent("carro_forte:startMission", source, {
        pickups   = pickups,
        delivery  = Config.DeliveryLocation,
        collected = 0,
        total     = numDeliveries,
    })

    print(("[CARRO FORTE] Jogador uid=%s iniciou missão com %d entregas."):format(tostring(uid), numDeliveries))
end)

-- ============================================================
--  CANCELAR JOB  (fechou a tela do caminhão sem spawnar)
-- ============================================================

RegisterServerEvent("carro_forte:cancelJob")
AddEventHandler("carro_forte:cancelJob", function()
    local source = source
    if not activeMissions[source] then return end

    activeMissions[source] = nil
    TriggerClientEvent("carro_forte:endMission", source, "quit")
    print(("[CARRO FORTE] Jogador %s cancelou antes de pegar o veículo."):format(tostring(source)))
end)

-- ============================================================
--  COLETAR DINHEIRO NO BANCO
-- ============================================================

RegisterServerEvent("carro_forte:collectMoney")
AddEventHandler("carro_forte:collectMoney", function(pickupIndex)
    local source  = source
    local mission = activeMissions[source]
    if not mission then return end

    local pickup = mission.pickups[pickupIndex]
    if not pickup or pickup.collected then return end

    -- Anti-cheat: verificar proximidade no servidor
    local ped    = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local dist   = #(coords - vector3(pickup.x, pickup.y, pickup.z))

    if dist > 12.0 then
        chatMsg(source, "Você está longe demais para coletar.")
        return
    end

    pickup.collected  = true
    mission.collected = mission.collected + 1

    TriggerClientEvent("carro_forte:updatePickup", source, mission.collected, mission.total)

    -- Chance de assalto
    if math.random() < Config.RobberyChance then
        TriggerClientEvent("carro_forte:robbery", source, { x = pickup.x, y = pickup.y, z = pickup.z })
    end

    print(("[CARRO FORTE] Jogador %s coletou banco #%d (%d/%d)."):format(
        tostring(getUserId(source)), pickupIndex, mission.collected, mission.total))
end)

-- ============================================================
--  ENTREGAR DINHEIRO NA RESERVA FEDERAL
-- ============================================================

RegisterServerEvent("carro_forte:deliverMoney")
AddEventHandler("carro_forte:deliverMoney", function()
    local source  = source
    local mission = activeMissions[source]
    if not mission then return end

    -- Verificar se todos os bancos foram coletados
    for _, p in ipairs(mission.pickups) do
        if not p.collected then
            chatMsg(source, "Você ainda precisa coletar todos os bancos!")
            return
        end
    end

    -- Anti-cheat: verificar proximidade do ponto de entrega
    local ped      = GetPlayerPed(source)
    local coords   = GetEntityCoords(ped)
    local delivery = Config.DeliveryLocation
    local dist     = #(coords - vector3(delivery.x, delivery.y, delivery.z))

    if dist > 12.0 then
        chatMsg(source, "Você está longe demais do ponto de entrega.")
        return
    end

    -- Calcular pagamento
    local base    = Config.PayPerDelivery * mission.total
    local rawPct  = mission.speedViolations * Config.SpeedPenalty
    local pct     = math.min(rawPct, Config.MaxSpeedPenalty)
    local penalty = math.floor(base * pct)
    local payment = math.max(base - penalty, 0)
    local bonus   = Config.BonusComplete

    -- Pagar
    giveMoney(source, payment + bonus)

    -- Notificar cliente
    TriggerClientEvent("carro_forte:paymentReceived", source, payment, bonus)

    if penalty > 0 then
        chatMsg(source, ("Penalidade por excesso de velocidade: -$%d"):format(penalty))
    end

    -- Encerrar missão
    activeMissions[source] = nil
    TriggerClientEvent("carro_forte:endMission", source, "complete")

    print(("[CARRO FORTE] Jogador uid=%s concluiu missão. Pagamento: $%d + bônus $%d (penalidade -$%d)."):format(
        tostring(getUserId(source)), payment, bonus, penalty))
end)

-- ============================================================
--  VIOLAÇÃO DE VELOCIDADE  (registra penalidade)
-- ============================================================

RegisterServerEvent("carro_forte:speedViolation")
AddEventHandler("carro_forte:speedViolation", function()
    local source  = source
    local mission = activeMissions[source]
    if mission then
        mission.speedViolations = mission.speedViolations + 1
    end
end)

-- ============================================================
--  VEÍCULO DESTRUÍDO → missão falhou
-- ============================================================

RegisterServerEvent("carro_forte:vehicleDestroyed")
AddEventHandler("carro_forte:vehicleDestroyed", function()
    local source = source
    if not activeMissions[source] then return end

    activeMissions[source] = nil
    TriggerClientEvent("carro_forte:endMission", source, "failed")
    chatMsg(source, "Sua missão foi encerrada porque o carro forte foi destruído.")
    print(("[CARRO FORTE] Missão do jogador %s falhou (veículo destruído)."):format(tostring(source)))
end)

-- ============================================================
--  DESCONEXÃO → limpar missão
-- ============================================================

AddEventHandler("playerDropped", function(reason)
    local source = source
    if activeMissions[source] then
        activeMissions[source] = nil
        print(("[CARRO FORTE] Missão cancelada: jogador %s desconectou (%s)."):format(tostring(source), reason))
    end
end)

-- ============================================================
--  COMANDO ADMIN: /resetcarroforte [id]
-- ============================================================

RegisterCommand("resetcarroforte", function(src, args)
    local target = tonumber(args[1]) or src
    if activeMissions[target] then
        activeMissions[target] = nil
        TriggerClientEvent("carro_forte:endMission", target, "quit")

        local msg = "[ADMIN] Missão de carro forte resetada para o jogador " .. target
        if src ~= 0 then
            TriggerClientEvent("chatMessage", src, "", {0, 255, 0}, msg)
        else
            print(msg)
        end
    else
        local msg = "[ADMIN] Jogador " .. target .. " não está em missão."
        if src ~= 0 then
            TriggerClientEvent("chatMessage", src, "", {255, 200, 0}, msg)
        else
            print(msg)
        end
    end
end, true)

print("[CARRO FORTE] Servidor carregado com sucesso!")
