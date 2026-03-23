-- ============================================================
--  CARRO FORTE — CLIENT/UI.LUA
--  Gerencia toda a interface NUI: despachante, tela do
--  caminhão, HUD da missão e notificações (toasts).
-- ============================================================

local vrp       = exports["vrp"]:getSharedObject()
local vrpClient = exports["vrp_client"]:getSharedObject()

local uiOpen   = false
local hudShown = false

-- ============================================================
--  INTERNOS
-- ============================================================

local function sendNUI(data)
    SendNUIMessage(data)
end

local function setFocus(state)
    SetNuiFocus(state, state)
    uiOpen = state
end

-- ============================================================
--  CF_Toast — notificação flutuante (chamada do main.lua)
--  tipo: "success" | "danger" | "warning" | "info" | "gold"
-- ============================================================

function CF_Toast(tipo, icon, titulo, msg, duracaoSeg)
    sendNUI({
        action = "toast",
        data   = {
            type     = tipo or "info",
            icon     = icon,
            title    = titulo,
            msg      = msg,
            duration = (duracaoSeg or 4) * 1000,
        }
    })
end

-- ============================================================
--  TELA 1 — DESPACHANTE
--  Aberta quando o servidor responde ao requestJob
-- ============================================================

RegisterNetEvent("carro_forte:showDispatcherMenu")
AddEventHandler("carro_forte:showDispatcherMenu", function()
    if uiOpen then return end

    sendNUI({
        action = "openDispatcher",
        data   = {
            label          = Config.JobLabel,
            payPerDelivery = Config.PayPerDelivery,
            bonus          = Config.BonusComplete,
            minDeliveries  = Config.MinDeliveries,
            maxDeliveries  = Config.MaxDeliveries,
            vehicle        = Config.VehicleLabel,
            speedLimit     = Config.SpeedLimit,
        }
    })

    setFocus(true)
end)

-- Jogador clicou em "Aceitar Missão"
RegisterNUICallback("acceptJob", function(data, cb)
    setFocus(false)
    sendNUI({ action = "closeAll" })
    TriggerServerEvent("carro_forte:acceptJob")
    cb("ok")
end)

-- Jogador clicou em "Recusar" ou pressionou ESC no despachante
RegisterNUICallback("declineJob", function(data, cb)
    setFocus(false)
    sendNUI({ action = "closeAll" })
    cb("ok")
end)

-- ============================================================
--  TELA 2 — PEGAR O CAMINHÃO
--  Exibida após o servidor processar o acceptJob
-- ============================================================

RegisterNetEvent("carro_forte:showTruckScreen")
AddEventHandler("carro_forte:showTruckScreen", function()
    -- Pequeno delay para não colidir com animações de fechamento
    Citizen.SetTimeout(350, function()
        sendNUI({
            action = "showTruckScreen",
            data   = {
                vehicleLabel = Config.VehicleLabel,
                spawnLabel   = "Garagem da Empresa",
                speedLimit   = Config.SpeedLimit,
            }
        })
        setFocus(true)
    end)
end)

-- Jogador clicou em "Pegar o Carro Forte"
RegisterNUICallback("spawnTruck", function(data, cb)
    setFocus(false)
    sendNUI({ action = "closeAll" })
    TriggerEvent("carro_forte:spawnVehicle")
    cb("ok")
end)

-- Jogador cancelou na tela do caminhão (ESC)
RegisterNUICallback("cancelTruck", function(data, cb)
    setFocus(false)
    sendNUI({ action = "closeAll" })
    TriggerServerEvent("carro_forte:cancelJob")
    cb("ok")
end)

-- Callback genérico de fechar (segurança)
RegisterNUICallback("closeMenu", function(data, cb)
    setFocus(false)
    sendNUI({ action = "closeAll" })
    cb("ok")
end)

-- ============================================================
--  HUD DA MISSÃO — exibido durante o transporte
-- ============================================================

function CF_ShowHUD(collected, total, earnings, bonus, penalty)
    hudShown = true
    sendNUI({
        action = "showHUD",
        data   = {
            collected      = collected or 0,
            total          = total     or 0,
            earnings       = earnings  or 0,
            bonus          = bonus     or Config.BonusComplete,
            penalty        = penalty   or 0,
            speedViolation = false,
        }
    })
end

function CF_UpdateHUD(collected, total, earnings, bonus, penalty, speedViolation)
    sendNUI({
        action = "updateHUD",
        data   = {
            collected      = collected      or 0,
            total          = total          or 0,
            earnings       = earnings       or 0,
            bonus          = bonus          or Config.BonusComplete,
            penalty        = penalty        or 0,
            speedViolation = speedViolation or false,
        }
    })
end

function CF_HideHUD()
    hudShown = false
    sendNUI({ action = "hideHUD" })
end

-- Handlers de rede (caso o servidor precise forçar atualização)
RegisterNetEvent("carro_forte:showHUD")
AddEventHandler("carro_forte:showHUD", function(d)
    CF_ShowHUD(d.collected, d.total, d.earnings, d.bonus, d.penalty)
end)

RegisterNetEvent("carro_forte:updateHUD")
AddEventHandler("carro_forte:updateHUD", function(d)
    CF_UpdateHUD(d.collected, d.total, d.earnings, d.bonus, d.penalty, d.speedViolation)
end)

-- ============================================================
--  FECHAR COM ESC
-- ============================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if uiOpen and IsControlJustReleased(0, 322) then  -- ESC
            setFocus(false)
            sendNUI({ action = "closeAll" })
            -- Se cancelou na tela do caminhão, avisa o servidor
            TriggerServerEvent("carro_forte:cancelJob")
        end
    end
end)
