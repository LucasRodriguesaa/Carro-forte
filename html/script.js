// ============================================================
// CARRO FORTE — NUI INTERATIVA
// ============================================================

// Referências de elementos
const screenDispatcher = document.getElementById('screen-dispatcher');
const screenTruck      = document.getElementById('screen-truck');
const hud              = document.getElementById('hud');
const toastsContainer  = document.getElementById('toasts');

let truckReady      = false;
let missionActive   = false;
let hudData         = { collected: 0, total: 0, earnings: 0, bonus: 5000, penalty: 0 };

// ============================================================
// MENSAGENS DO LUA → NUI
// ============================================================

window.addEventListener('message', function(e) {
    const { action, data } = e.data;

    switch (action) {

        /* Abrir menu do despachante */
        case 'openDispatcher':
            openDispatcher(data);
            break;

        /* Fechar tudo */
        case 'closeAll':
            closeAll();
            break;

        /* Mostrar tela de pegar caminhão */
        case 'showTruckScreen':
            showTruckScreen(data);
            break;

        /* Fechar tela de caminhão (após spawn) */
        case 'closeTruckScreen':
            closeTruckScreen();
            break;

        /* Mostrar / esconder HUD */
        case 'showHUD':
            showHUD(data);
            break;
        case 'hideHUD':
            hideHUD();
            break;

        /* Atualizar HUD */
        case 'updateHUD':
            updateHUD(data);
            break;

        /* Notificações toast */
        case 'toast':
            showToast(data.type, data.icon, data.title, data.msg);
            break;
    }
});

// ============================================================
// TELA 1 — DESPACHANTE
// ============================================================

function openDispatcher(data) {
    if (data) {
        document.getElementById('mi-pay').textContent   = formatMoney(data.payPerDelivery || 1500);
        document.getElementById('mi-bonus').textContent = formatMoney(data.bonus || 5000);
        document.getElementById('mi-range').textContent =
            (data.minDeliveries || 3) + ' – ' + (data.maxDeliveries || 6);
        document.getElementById('mi-speed').textContent = (data.speedLimit || 80) + ' km/h';
        hudData.bonus = data.bonus || 5000;
    }

    screenDispatcher.classList.remove('hidden');
    screenTruck.classList.add('hidden');
    hideHUD();
    setNuiFocus(true);
}

function acceptJob() {
    screenDispatcher.classList.add('hidden');
    post('acceptJob');
    showToast('info', '📋', 'Missão aceita!', 'Prepare-se para pegar o carro forte.');
}

function declineJob() {
    screenDispatcher.classList.add('hidden');
    post('declineJob');
    setNuiFocus(false);
}

// ============================================================
// TELA 2 — PEGAR O CAMINHÃO
// ============================================================

function showTruckScreen(data) {
    if (data) {
        document.getElementById('truckName').textContent     = data.vehicleLabel  || 'Stockade';
        document.getElementById('truckLocation').textContent = data.spawnLabel    || 'Garagem Central';
        document.getElementById('truckSpeed').textContent    = (data.speedLimit   || 80) + ' km/h';
    }

    truckReady = false;
    document.getElementById('truckBtn').disabled     = true;
    document.getElementById('truckBtnText').textContent = 'Aguardando...';
    document.getElementById('truckSpinner').classList.add('hidden');

    // Resetar checklist
    ['chk-equip','chk-vehicle','chk-route'].forEach(id => {
        const dot = document.querySelector(`#${id} .chk-dot`);
        dot.className = 'chk-dot loading';
    });

    screenTruck.classList.remove('hidden');
    screenDispatcher.classList.add('hidden');
    setNuiFocus(true);

    // Simular verificações uma a uma
    runChecklist();
}

function runChecklist() {
    const steps = ['chk-equip', 'chk-vehicle', 'chk-route'];
    const labels = {
        'chk-equip':   'Equipamentos verificados ✓',
        'chk-vehicle': 'Veículo blindado pronto ✓',
        'chk-route':   'Rotas calculadas ✓',
    };

    let i = 0;
    function next() {
        if (i >= steps.length) {
            // Tudo pronto — liberar botão
            truckReady = true;
            document.getElementById('truckBtn').disabled = false;
            document.getElementById('truckBtnText').textContent = '🚛 Pegar o Carro Forte';
            return;
        }
        const id  = steps[i];
        const el  = document.getElementById(id);
        const dot = el.querySelector('.chk-dot');
        const txt = el.querySelector('span:last-child');

        dot.className = 'chk-dot done';
        txt.textContent = labels[id];
        txt.style.color = '#34d399';
        i++;
        setTimeout(next, 700);
    }

    setTimeout(next, 600);
}

function spawnTruck() {
    if (!truckReady) return;
    truckReady = false;

    // Mostrar spinner no botão
    document.getElementById('truckBtn').disabled = true;
    document.getElementById('truckSpinner').classList.remove('hidden');
    document.getElementById('truckBtnText').textContent = 'Spawnando...';

    post('spawnTruck');

    // Fechar após 1.2s (o Lua também vai fechar via closeTruckScreen)
    setTimeout(() => {
        closeTruckScreen();
        setNuiFocus(false);
    }, 1200);
}

function closeTruckScreen() {
    screenTruck.classList.add('hidden');
    setNuiFocus(false);
}

// ============================================================
// FECHAR TUDO
// ============================================================

function closeAll() {
    screenDispatcher.classList.add('hidden');
    screenTruck.classList.add('hidden');
    setNuiFocus(false);
}

// ============================================================
// HUD DA MISSÃO
// ============================================================

function showHUD(data) {
    hud.classList.remove('hidden');
    if (data) {
        hudData = { ...hudData, ...data };
        renderHUD();
    }
}

function hideHUD() {
    hud.classList.add('hidden');
}

function updateHUD(data) {
    hudData = { ...hudData, ...data };
    renderHUD();
}

function renderHUD() {
    const { collected, total, earnings, bonus, penalty, speedViolation } = hudData;

    // Barra de progresso
    const pct = total > 0 ? (collected / total) * 100 : 0;
    document.getElementById('hudProgressFill').style.width = pct + '%';
    document.getElementById('hudProgressText').textContent =
        collected + ' / ' + total + ' banco' + (total !== 1 ? 's' : '');

    // Valores
    document.getElementById('hudEarnings').textContent = formatMoney(earnings || 0);
    document.getElementById('hudBonus').textContent    = formatMoney(bonus    || 0);
    document.getElementById('hudPenalty').textContent  = penalty > 0
        ? '-' + formatMoney(penalty) : '$0';

    // Alerta de velocidade
    const alert = document.getElementById('hudSpeedAlert');
    if (speedViolation) {
        alert.classList.remove('hidden');
    } else {
        alert.classList.add('hidden');
    }

    // Mudar status do HUD se todos coletados
    const status = document.getElementById('hudStatus');
    if (total > 0 && collected >= total) {
        status.textContent = 'Entregar!';
        status.style.background = 'rgba(251,191,36,0.15)';
        status.style.color      = '#fbbf24';
        status.style.borderColor= 'rgba(251,191,36,0.3)';
    } else {
        status.textContent = 'Em missão';
        status.style.background = '';
        status.style.color      = '';
        status.style.borderColor= '';
    }
}

// ============================================================
// TOASTS — Notificações
// ============================================================

const TOAST_DEFAULTS = {
    success: { icon: '✅', title: 'Sucesso' },
    danger:  { icon: '🚨', title: 'Alerta' },
    warning: { icon: '⚠️', title: 'Atenção' },
    info:    { icon: 'ℹ️', title: 'Info' },
    gold:    { icon: '💰', title: 'Pagamento' },
};

function showToast(type = 'info', icon, title, msg, duration = 4000) {
    const def = TOAST_DEFAULTS[type] || TOAST_DEFAULTS.info;
    const finalIcon  = icon  || def.icon;
    const finalTitle = title || def.title;

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <div class="toast-icon">${finalIcon}</div>
        <div class="toast-body">
            <div class="toast-title">${finalTitle}</div>
            ${msg ? `<div class="toast-msg">${msg}</div>` : ''}
        </div>
    `;

    toastsContainer.appendChild(toast);

    setTimeout(() => {
        toast.classList.add('leaving');
        setTimeout(() => toast.remove(), 320);
    }, duration);
}

// ============================================================
// FECHAR COM ESC
// ============================================================

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        if (!screenDispatcher.classList.contains('hidden')) {
            declineJob();
        } else if (!screenTruck.classList.contains('hidden')) {
            post('cancelTruck');
            closeTruckScreen();
        }
    }
});

// ============================================================
// UTILITÁRIOS
// ============================================================

function formatMoney(v) {
    return '$' + Number(v).toLocaleString('pt-BR');
}

function post(event, data = {}) {
    fetch(`https://carro-forte/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function setNuiFocus(state) {
    // Em produção o foco é controlado pelo Lua via SetNuiFocus
    // Esta função existe como placeholder para testes no browser
}
