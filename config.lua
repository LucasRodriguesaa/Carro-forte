-- ============================================================
--  CARRO FORTE — CONFIG.LUA
--  Todas as configurações do script ficam aqui.
--  Não edite os outros arquivos para ajustar comportamento.
-- ============================================================

Config = {}

-- ============================================================
--  1. INFORMAÇÕES DO JOB
-- ============================================================

Config.JobName  = "carro_forte"       -- nome interno (vRPEx group)
Config.JobLabel = "Transporte de Valores"

-- Se true  → só jogadores com o grupo Config.JobName podem trabalhar
-- Se false → qualquer jogador pode usar o trabalho
Config.RequireJob = false

-- ============================================================
--  2. LOCALIZAÇÃO DE INÍCIO DO TRABALHO
--     O jogador se aproxima deste ponto e aperta E para abrir
--     o menu do despachante. Nenhum comando é necessário.
-- ============================================================

Config.JobLocation = {
    x       = 225.4,    -- coordenada X
    y       = -808.3,   -- coordenada Y
    z       = 30.7,     -- coordenada Z
    heading = 270.0,    -- direção do NPC (0=Norte 90=Leste 180=Sul 270=Oeste)

    -- Texto que aparece no mapa (blip)
    blipLabel  = "Carro Forte",
    blipSprite = 67,     -- ícone do blip (67 = carro forte)
    blipColor  = 5,      -- cor amarela
    blipScale  = 0.9,

    -- Texto que aparece na tela quando o jogador está perto
    interactText = "Pressione ~g~E~w~ para falar com o Despachante",

    -- Distância para exibir o texto de interação
    interactDistance = 3.5,
}

-- ============================================================
--  3. VEÍCULO DO CARRO FORTE
-- ============================================================

Config.Vehicle      = "stockade"     -- nome do modelo GTA
Config.VehicleLabel = "Stockade Blindado"
Config.VehiclePlate = "CFORTE"       -- placa personalizada

-- Onde o veículo vai spawnar ao iniciar (próximo ao JobLocation)
Config.SpawnPoint = {
    x       = 228.0,
    y       = -812.0,
    z       = 30.7,
    heading = 270.0,
}

-- ============================================================
--  4. PAGAMENTOS
-- ============================================================

-- Tipo de dinheiro: "money" = limpo | "dirty_money" = sujo
Config.MoneyType = "money"

-- Valor recebido por cada banco coletado
Config.PayPerDelivery = 1500

-- Bônus extra ao completar TODOS os bancos da missão
Config.BonusComplete = 5000

-- ============================================================
--  5. MISSÃO — ENTREGAS
-- ============================================================

-- Quantidade mínima e máxima de bancos por missão (sorteado a cada vez)
Config.MinDeliveries = 3
Config.MaxDeliveries = 6

-- Distância máxima para coletar/entregar (apertar E)
Config.InteractionDistance = 3.5

-- ============================================================
--  6. VELOCIDADE & PENALIDADES
-- ============================================================

-- Limite de velocidade durante o transporte (km/h)
Config.SpeedLimit = 80

-- Desconto por cada violação de velocidade detectada (0.20 = 20%)
Config.SpeedPenalty = 0.20

-- Máximo de desconto acumulado (0.80 = 80% no máximo)
Config.MaxSpeedPenalty = 0.80

-- ============================================================
--  7. ASSALTOS NPC
-- ============================================================

-- Chance de assalto a cada banco coletado (0.0 = nunca | 1.0 = sempre)
Config.RobberyChance = 0.30

-- Número de NPCs que aparecem no assalto
Config.RobberyPedCount = 3

-- Modelo do NPC assaltante (nome do ped model do GTA)
Config.RobberyPedModel = "g_m_y_lost_01"

-- Arma dos assaltantes
Config.RobberyWeapon = "weapon_pistol"

-- ============================================================
--  8. LOCAIS DE COLETA (bancos e empresas)
--     Adicione ou remova entradas à vontade.
--     Campos: label, x, y, z
-- ============================================================

Config.PickupLocations = {
    {
        label = "Banco Fleeca — Centro",
        x = 149.6,  y = -1042.9, z = 29.4,
    },
    {
        label = "Banco Fleeca — Rockford Hills",
        x = -351.8, y = -49.3,   z = 49.0,
    },
    {
        label = "Banco Fleeca — Sandy Shores",
        x = 1175.0, y = 2706.7,  z = 38.1,
    },
    {
        label = "Banco Fleeca — Chumash",
        x = -2962.0, y = 482.8,  z = 15.7,
    },
    {
        label = "Banco Fleeca — Paleto Bay",
        x = -101.9, y = 6469.8,  z = 31.6,
    },
    {
        label = "Banco Fleeca — Vinewood",
        x = 314.2,  y = -280.7,  z = 54.2,
    },
    {
        label = "Banco Maze — Centro",
        x = -1213.0, y = -331.0, z = 37.8,
    },
    {
        label = "União de Crédito — Del Perro",
        x = -2963.3, y = 480.9,  z = 15.7,
    },
}

-- ============================================================
--  9. LOCAL DE ENTREGA (cofre central / reserva federal)
-- ============================================================

Config.DeliveryLocation = {
    label = "Reserva Federal de Los Santos",
    x     = 238.5,
    y     = 214.4,
    z     = 106.3,
}

-- ============================================================
--  10. BLIPS DOS BANCOS (durante a missão)
-- ============================================================

Config.PickupBlip = {
    sprite = 501,   -- cifrão
    color  = 2,     -- verde
    scale  = 0.75,
}

Config.DeliveryBlip = {
    sprite = 67,    -- banco
    color  = 5,     -- amarelo
    scale  = 0.9,
}
