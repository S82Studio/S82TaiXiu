// ═══════════════════════════════════════════════════════
// S82 TÀI XỈU — FRONTEND SCRIPT v1.0
// ═══════════════════════════════════════════════════════

// ── State ──────────────────────────────────────────────
let gameState = {
    round:    1,
    time:     600,
    betting:  true,
    rolling:  false,
    lockAt:   30,
    maxTime:  600,
};

let playerBalance  = 0;
let playerBet      = null;  // { choice, amount } or null
let config = {
    minBet: 50000,
    maxBet: 5000000,
    payoutRate: 1.9,
};

// ── Petal generator ───────────────────────────────────
(function spawnPetals() {
    const container = document.getElementById('petals-container');
    const PETAL_COUNT = 20;
    for (let i = 0; i < PETAL_COUNT; i++) {
        const p = document.createElement('div');
        p.className = 'petal';
        const size = (Math.random() * 10 + 8) + 'px';
        p.style.left = (Math.random() * 100) + '%';
        p.style.width = size;
        p.style.height = size;
        p.style.animationDuration = (Math.random() * 12 + 8) + 's';
        p.style.animationDelay    = (Math.random() * 12) + 's';
        container.appendChild(p);
    }
})();

// ── Helpers ────────────────────────────────────────────
function formatMoney(n) {
    n = parseInt(n) || 0;
    if (n >= 1000000) return (n / 1000000).toFixed(1).replace('.0','') + 'M';
    if (n >= 1000)    return (n / 1000).toFixed(0) + 'K';
    return n.toLocaleString('vi-VN');
}

function formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return String(m).padStart(2,'0') + ':' + String(s).padStart(2,'0');
}

function el(id) { return document.getElementById(id); }

// ── Main message handler ───────────────────────────────
window.addEventListener('message', ({ data: d }) => {

    if (d.action === 'open') {
        document.body.classList.add('visible');
        return;
    }

    if (d.action === 'close') {
        document.body.classList.remove('visible');
        removeOverlays();
        playerBet = null;
        el('currentBet').classList.remove('visible');
        return;
    }

    if (d.action === 'update') {
        applyUpdate(d.data);
        if (d.data.pool) updatePool(d.data.pool);
        return;
    }

    if (d.action === 'locked') {
        applyLocked();
        return;
    }

    if (d.action === 'result') {
        applyResult(d.data);
        return;
    }

    if (d.action === 'newRound') {
        applyNewRound(d.data);
        return;
    }

    if (d.action === 'history') {
        renderHistory(d.history);
        return;
    }

    if (d.action === 'betPlaced') {
        playerBet = d.data;
        showCurrentBet(d.data);
        disableBetButtons();
        return;
    }

    if (d.action === 'receiveUIData') {
        const dd = d.data;
        gameState.round   = dd.round;
        gameState.time    = dd.time;
        gameState.betting = dd.betting;
        gameState.rolling = dd.rolling;
        gameState.lockAt  = dd.lockAt;
        gameState.maxTime = gameState.maxTime || dd.time;

        if (dd.minBet)     config.minBet     = dd.minBet;
        if (dd.maxBet)     config.maxBet     = dd.maxBet;
        if (dd.payoutRate) config.payoutRate = dd.payoutRate;

        if (typeof dd.balance !== 'undefined') {
            playerBalance = dd.balance;
            el('balanceDisplay').textContent = formatMoney(dd.balance);
        }

        if (dd.playerBet) {
            playerBet = dd.playerBet;
            showCurrentBet(dd.playerBet);
            disableBetButtons();
        }

        if (dd.history) renderHistory(dd.history);
        if (dd.pool)    updatePool(dd.pool);

        applyUpdate({ round: dd.round, time: dd.time, betting: dd.betting, rolling: dd.rolling, lockAt: dd.lockAt });
        return;
    }

    if (d.action === 'poolUpdate') {
        updatePool(d.pool);
        return;
    }

    if (d.action === 'updateBalance') {
        playerBalance = d.balance;
        el('balanceDisplay').textContent = formatMoney(d.balance);
        return;
    }

    if (d.action === 'receiveStats') {
        // Reserved for stats display if needed
        return;
    }
});

// ── Update timer / state ───────────────────────────────
function applyUpdate(data) {
    gameState = { ...gameState, ...data };

    el('roundNum').textContent = data.round;
    el('timeValue').textContent = formatTime(data.time);

    const maxTime = 600; // fallback
    const pct = Math.max(0, (data.time / maxTime) * 100);
    el('timerBar').style.width = pct + '%';

    // Color classes
    const tv = el('timeValue');
    const tb = el('timerBar');
    tv.classList.remove('warning', 'danger');
    tb.classList.remove('warning', 'danger');

    if (data.rolling) {
        el('statusDot').className = 'status-dot rolling';
        el('statusText').textContent = 'Đang lắc xúc xắc...';
    } else if (!data.betting) {
        el('statusDot').className = 'status-dot locked';
        el('statusText').textContent = 'Đã khóa cược • Sắp quay!';
        tv.classList.add(data.time <= 10 ? 'danger' : 'warning');
        tb.classList.add(data.time <= 10 ? 'danger' : 'warning');
    } else {
        el('statusDot').className = 'status-dot';
        el('statusText').textContent = 'Đang nhận cược';

        const timeLeft = data.time - data.lockAt;
        if (timeLeft <= 60) tv.classList.add('warning');
    }

    // Sync button states
    if (!data.betting || data.rolling || playerBet) {
        disableBetButtons();
    } else {
        enableBetButtons();
    }
}

// ── Locked phase ───────────────────────────────────────
function applyLocked() {
    gameState.betting = false;
    el('statusDot').className = 'status-dot locked';
    el('statusText').textContent = 'Đã khóa cược • Sắp quay!';
    disableBetButtons();

    // Show locked overlay only if no bet placed
    if (!playerBet) {
        showLockedOverlay();
    }
}

function showLockedOverlay() {
    removeOverlays();
    const ov = document.createElement('div');
    ov.className = 'locked-overlay';
    ov.id = 'lockedOverlay';
    ov.innerHTML = `
        <div class="locked-msg">
            <h2>🔒 Đã Khóa Cược</h2>
            <p>Xúc xắc sắp được lắc...</p>
        </div>
    `;
    el('panel').appendChild(ov);
    setTimeout(() => removeOverlays(), 31000);
}

function removeOverlays() {
    ['lockedOverlay'].forEach(id => {
        const ov = el(id);
        if (ov) ov.remove();
    });
}

// ── Result ─────────────────────────────────────────────
function applyResult(data) {
    removeOverlays();
    gameState.rolling = true;
    gameState.betting = false;

    el('statusDot').className = 'status-dot rolling';
    el('statusText').textContent = 'Đang lắc xúc xắc...';

    const dice = [el('die1'), el('die2'), el('die3')];
    const vals  = [el('dv1'),  el('dv2'),  el('dv3')];

    // Reset dice colors
    dice.forEach(d => {
        d.className = 'die rolling';
    });

    // Show rolling ? first
    vals.forEach(v => { v.textContent = '?'; });

    // Reveal after animation
    setTimeout(() => {
        dice.forEach((d, i) => {
            d.classList.remove('rolling');
            d.classList.add(data.result + '-result');
            vals[i].textContent = data.dice[i];
        });

        // Show result badge
        const badge = el('resultBadge');
        badge.className = 'result-badge ' + data.result;
        el('resultTotal').textContent = data.total;
        el('resultLabel').textContent = data.result === 'tai' ? 'TÀI' : data.result === 'xiu' ? 'XỈU' : 'HÒA';

        // History updated comes separately
        renderHistory(data.history);

        el('statusDot').className = 'status-dot locked';
        el('statusText').textContent =
            data.result === 'tai' ? '🔴 Kết quả: TÀI (' + data.total + ')' :
            data.result === 'xiu' ? '🔵 Kết quả: XỈU (' + data.total + ')' :
                                    '🟡 Kết quả: HÒA (' + data.total + ')';
    }, 800);
}

// ── New round ──────────────────────────────────────────
function applyNewRound(data) {
    gameState.rolling = false;
    gameState.betting = true;
    playerBet = null;

    // Reset dice display
    ['dv1','dv2','dv3'].forEach(id => { el(id).textContent = '?'; });
    ['die1','die2','die3'].forEach(id => { el(id).className = 'die'; });

    // Hide result badge
    el('resultBadge').className = 'result-badge hidden';

    // Reset bet UI
    el('currentBet').classList.remove('visible');
    enableBetButtons();
    removeOverlays();

    // Reset pool
    updatePool({ taiTotal: 0, xiuTotal: 0, taiCount: 0, xiuCount: 0 });

    el('statusDot').className = 'status-dot';
    el('statusText').textContent = 'Đang nhận cược';
}

// ── Bet Pool ───────────────────────────────────────────
function updatePool(pool) {
    if (!pool) return;

    const taiEl = el('taiPool');
    const xiuEl = el('xiuPool');

    taiEl.textContent = formatMoney(pool.taiTotal || 0);
    xiuEl.textContent = formatMoney(pool.xiuTotal || 0);

    // Bump animation khi có thay đổi
    [taiEl, xiuEl].forEach(el => {
        el.classList.remove('bump');
        void el.offsetWidth;
        el.classList.add('bump');
        setTimeout(() => el.classList.remove('bump'), 300);
    });
}

// ── History rendering ──────────────────────────────────
function renderHistory(history) {
    const row = el('historyRow');
    if (!history || history.length === 0) {
        row.innerHTML = '<div class="history-empty">Chưa có dữ liệu</div>';
        return;
    }

    row.innerHTML = '';
    history.forEach((item, idx) => {
        const r = typeof item === 'object' ? item.result : item;
        const t = typeof item === 'object' ? item.total  : null;

        const div = document.createElement('div');
        div.className = 'hist-item';
        div.style.animationDelay = (idx * 0.06) + 's';

        const label = r === 'tai' ? 'T' : r === 'xiu' ? 'X' : 'H';

        div.innerHTML = `
            <div class="hist-chip ${r}">${label}</div>
            ${t !== null ? `<div class="hist-total">${t}</div>` : ''}
        `;
        row.appendChild(div);
    });
}

// ── Bet buttons ────────────────────────────────────────
function disableBetButtons() {
    el('taiBtnMain').classList.add('disabled');
    el('xiuBtnMain').classList.add('disabled');
}

function enableBetButtons() {
    if (playerBet) return; // already bet
    el('taiBtnMain').classList.remove('disabled');
    el('xiuBtnMain').classList.remove('disabled');
}

function showCurrentBet(bet) {
    const cb = el('currentBet');
    const ch = el('cbChoice');
    ch.textContent = bet.choice === 'tai' ? 'TÀI' : 'XỈU';
    ch.className   = 'cb-choice ' + bet.choice;
    el('cbAmount').textContent = formatMoney(bet.amount);
    cb.classList.add('visible');
}

// ── Bet action ─────────────────────────────────────────
function placeBet(choice) {
    if (!gameState.betting || gameState.rolling || playerBet) return;

    const amountRaw = parseInt(el('betAmount').value) || 0;
    if (amountRaw < config.minBet) {
        showInputError('Tối thiểu ' + formatMoney(config.minBet));
        return;
    }
    if (amountRaw > config.maxBet) {
        showInputError('Tối đa ' + formatMoney(config.maxBet));
        return;
    }
    if (amountRaw > playerBalance) {
        showInputError('Không đủ tiền!');
        return;
    }

    fetch(`https://${GetParentResourceName()}/bet`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ choice, amount: amountRaw }),
    });
}

function showInputError(msg) {
    const input = el('betAmount');
    input.placeholder = msg;
    input.style.borderColor = 'var(--tai-color)';
    setTimeout(() => {
        input.placeholder = 'Nhập số tiền...';
        input.style.borderColor = '';
    }, 2000);
}

// ── Quick amount buttons ───────────────────────────────
function setAmount(value) {
    el('betAmount').value = value;
    const input = el('betAmount');
    input.style.transform = 'scale(1.03)';
    setTimeout(() => { input.style.transform = ''; }, 150);
}

function setMaxAmount() {
    const maxAllowed = Math.min(config.maxBet, playerBalance);
    el('betAmount').value = maxAllowed;
    const input = el('betAmount');
    input.style.transform = 'scale(1.03)';
    setTimeout(() => { input.style.transform = ''; }, 150);
}

// ── Close button ───────────────────────────────────────
el('closeBtn').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
});

// ── Keyboard shortcuts ─────────────────────────────────
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
    }
    if (e.key === 'Enter' && gameState.betting && !playerBet) {
        // Enter does nothing by default — require explicit click
    }
});

// ── Prevent scroll ─────────────────────────────────────
document.addEventListener('wheel', e => e.preventDefault(), { passive: false });