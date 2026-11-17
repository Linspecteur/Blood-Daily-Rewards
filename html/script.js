'use strict';

/* ==========================================================
   bl_daily — NUI
   L'UI n'envoie jamais de montant ni d'item : elle demande
   seulement "claim", le serveur décide de tout.
   ========================================================== */

const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'bl_daily';
const $ = (id) => document.getElementById(id);

const els = {
    // Menu
    app: $('app'),
    days: $('days'),
    progress: $('progress'),
    streak: $('streak-value'),
    banner: $('banner'),
    rule: $('rule-text'),
    claimBtn: $('claim-btn'),
    claimIcon: $('claim-icon'),
    claimLabel: $('claim-label'),
    countdown: $('countdown'),
    countdownValue: $('countdown-value'),
    cycleDone: $('cycle-done'),
    closeBtn: $('close-btn'),
    // Pop-up
    popup: $('popup'),
    popupDay: $('popup-day'),
    popupTag: $('popup-tag'),
    popupTitle: $('popup-title'),
    popupSub: $('popup-sub'),
    popupKey: $('popup-key'),
    popupTimer: $('popup-timer'),
    // Notifications
    toasts: $('toasts')
};

const ACCOUNTS = ['money', 'bank', 'black_money'];

const ICONS = {
    money: 'fa-money-bill-wave',
    bank: 'fa-building-columns',
    black_money: 'fa-sack-dollar',
    item: 'fa-box-open'
};

const RARITY_ICONS = {
    common: 'fa-circle',
    rare: 'fa-diamond',
    epic: 'fa-gem',
    legendary: 'fa-crown'
};

const STATE_META = {
    claimed: { icon: 'fa-check', key: 'claimed' },
    current: { icon: 'fa-gift', key: 'today' },
    next: { icon: 'fa-clock', key: 'next' },
    locked: { icon: 'fa-lock', key: 'locked' }
};

let locale = {};
let status = null;
let visible = false;
let claiming = false;
let hideTimer = null;
let countdownTimer = null;
let countdownEnd = 0;
let popupTimer = null;

/* ---------- Utilitaires ---------- */

function post(name, data = {}) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    })
        .then((res) => res.json())
        .catch(() => null);
}

function t(key, vars) {
    let str = locale[key] ?? key;
    if (vars) {
        for (const [k, v] of Object.entries(vars)) str = str.replaceAll(`{${k}}`, v);
    }
    return str;
}

function esc(value) {
    return String(value ?? '').replace(/[&<>"']/g, (c) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    })[c]);
}

function formatNumber(n) {
    return String(Math.floor(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

function formatTime(total) {
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    return [h, m, s].map((v) => String(v).padStart(2, '0')).join(':');
}

// Lua encode un tableau vide en objet : on normalise
const asArray = (v) => (Array.isArray(v) ? v : Object.values(v || {}));

// Découpe une récompense en : argent, items, bonus
function parseReward(reward = {}) {
    const entries = asArray(reward.entries);
    const cash = entries.filter((e) => ACCOUNTS.includes(e.type));
    return {
        rarity: RARITY_ICONS[reward.rarity] ? reward.rarity : 'common',
        cash,
        total: cash.reduce((sum, e) => sum + e.amount, 0),
        items: entries.filter((e) => e.type === 'item'),
        bonus: entries.find((e) => e.type === 'bonus')
    };
}

function rarityHTML(rarity) {
    return `<i class="fa-solid ${RARITY_ICONS[rarity]}"></i>${esc(t(`rarity_${rarity}`))}`;
}

function entryIcon(entry, imagePath) {
    if (entry.type === 'item' && imagePath) {
        const src = imagePath.replace('%s', encodeURIComponent(entry.name));
        return `<div class="reward-icon"><img src="${esc(src)}" alt=""></div>`;
    }
    return `<div class="reward-icon"><i class="fa-solid ${ICONS[entry.type] || ICONS.item}"></i></div>`;
}

// Image d'item absente -> icône générique
function bindImageFallbacks(container) {
    container.querySelectorAll('.reward-icon img').forEach((img) => {
        img.addEventListener('error', () => {
            img.parentElement.innerHTML = `<i class="fa-solid ${ICONS.item}"></i>`;
        }, { once: true });
    });
}

/* ---------- États des jours ---------- */

function dayState(day) {
    if (status.canClaim) {
        if (day < status.nextDay) return 'claimed';
        return day === status.nextDay ? 'current' : 'locked';
    }
    if (day <= status.streak) return 'claimed';
    if (day === status.nextDay && status.streak < status.cycle) return 'next';
    return 'locked';
}

/* ---------- Rendu des cartes ---------- */

function cardHTML(reward, index) {
    const day = reward.day;
    const state = dayState(day);
    const meta = STATE_META[state];
    const big = day === status.cycle;
    const r = parseReward(reward);

    const headline = r.total > 0 ? `
        <div class="headline">
            <b>${formatNumber(r.total)}<small>${esc(t('currency'))}</small></b>
            <span>${r.cash.map((e) => esc(t(e.type))).join(' + ')}</span>
        </div>` : '';

    const bonus = r.bonus ? `
        <div class="bonus">
            <i class="fa-solid fa-dice"></i><span>${esc(t('bonus'))}</span>
            <b>${esc(t('bonus_range', { min: formatNumber(r.bonus.min), max: formatNumber(r.bonus.max) }))} ${esc(t('currency'))}</b>
        </div>` : '';

    const tiles = r.items.length ? `
        <div class="item-tiles">
            ${r.items.slice(0, big ? 6 : 3).map((e) => `
                <div class="item-tile" title="${esc(e.label)}">
                    ${entryIcon(e, status.imagePath)}
                    <span class="count">x${e.count}</span>
                    <span class="name">${esc(e.label)}</span>
                </div>`).join('')}
        </div>` : '';

    const empty = !headline && !bonus && !tiles ? `<p class="empty">${esc(t('empty'))}</p>` : '';

    return `
        <article class="day-card state-${state} rarity-${r.rarity}${big ? ' big' : ''}" data-day="${day}" style="--i:${index}">
            <div class="day-head">
                <span class="day-num">${esc(t('day'))} ${day}</span>
                <span class="day-state"><i class="fa-solid ${meta.icon}"></i>${esc(t(meta.key))}</span>
            </div>
            <div class="day-body">
                ${big ? `<span class="big-ribbon"><i class="fa-solid fa-crown"></i>${esc(t('big_reward'))}</span>
                         <div class="big-visual"><i class="fa-solid fa-gift"></i></div>` : ''}
                <span class="rarity">${rarityHTML(r.rarity)}</span>
                ${reward.label ? `<div class="day-title">${esc(reward.label)}</div>` : ''}
                ${headline}${bonus}${tiles}${empty}
            </div>
            <div class="stamp"><i class="fa-solid fa-check"></i></div>
        </article>`;
}

function setClaimButton(mode) {
    els.claimBtn.classList.remove('loading', 'success', 'shake');

    if (mode === 'loading') {
        els.claimBtn.classList.add('loading');
        els.claimIcon.className = 'fa-solid fa-circle-notch fa-spin';
        els.claimLabel.textContent = t('claiming');
    } else if (mode === 'success') {
        els.claimBtn.classList.add('success');
        els.claimIcon.className = 'fa-solid fa-check';
        els.claimLabel.textContent = t('claimed_button');
    } else {
        els.claimIcon.className = 'fa-solid fa-gift';
        els.claimLabel.textContent = t('claim_button', { day: status.nextDay });
    }
}

function render(newStatus, { animate = true } = {}) {
    status = newStatus;
    status.rewards = asArray(status.rewards);
    status.cycle = status.cycle || status.rewards.length;

    const done = status.canClaim ? status.nextDay - 1 : status.streak;
    els.streak.textContent = `${done} / ${status.cycle}`;

    els.progress.innerHTML = status.rewards
        .map((r) => `<span class="seg seg-${dayState(r.day)}"></span>`)
        .join('');

    els.banner.classList.toggle('hidden', !status.streakLost);
    els.rule.textContent = t(status.resetOnMiss ? 'reset_warning' : 'no_reset');

    els.days.classList.toggle('no-anim', !animate);
    els.days.innerHTML = status.rewards.map(cardHTML).join('');
    bindImageFallbacks(els.days);

    if (status.canClaim) {
        stopCountdown();
        setClaimButton('idle');
        els.claimBtn.classList.remove('hidden');
        els.countdown.classList.add('hidden');
    } else {
        els.claimBtn.classList.add('hidden');
        els.countdown.classList.remove('hidden');
        els.cycleDone.classList.toggle('hidden', status.streak < status.cycle);
        startCountdown(status.nextIn);
    }
}

/* ---------- Compte à rebours ---------- */

function stopCountdown() {
    clearInterval(countdownTimer);
    countdownTimer = null;
}

function startCountdown(seconds) {
    stopCountdown();
    countdownEnd = Date.now() + Math.max(1, seconds) * 1000;
    tick();
    countdownTimer = setInterval(tick, 1000);
}

function tick() {
    const left = Math.max(0, Math.round((countdownEnd - Date.now()) / 1000));
    els.countdownValue.textContent = formatTime(left);

    if (left <= 0) {
        stopCountdown();
        refresh();
    }
}

// Le serveur reste seul juge : on lui redemande le statut
async function refresh(attempt = 0) {
    if (!visible) return;
    const s = await post('refresh');
    if (!visible) return;

    if (s) {
        render(s, { animate: false });
    } else if (attempt < 5) {
        setTimeout(() => refresh(attempt + 1), 2000);
    }
}

/* ---------- Notifications (dans l'interface, au-dessus du menu) ---------- */

const TOAST_DURATION = 5000;
const TOAST_MAX = 3;
const TOAST_ICONS = {
    success: '<svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg>',
    error: '<svg viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>',
    warning: '<svg viewBox="0 0 24 24"><path d="M12 9v4"/><path d="M12 17h.01"/><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/></svg>',
    info: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>'
};
const recentToasts = new Set();

function toast(message, type = 'info') {
    if (!message) return;
    if (!TOAST_ICONS[type]) type = 'info';

    // Pas deux fois la même notification en moins de 2 s
    const key = `${type}:${message}`;
    if (recentToasts.has(key)) return;
    recentToasts.add(key);
    setTimeout(() => recentToasts.delete(key), 2000);

    // Les textes du config utilisent **gras** (format ox_lib)
    const html = esc(message).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');

    const el = document.createElement('div');
    el.className = `toast toast-${type}`;
    el.setAttribute('role', type === 'error' ? 'alert' : 'status');
    el.innerHTML = `
        <span class="toast-icon">${TOAST_ICONS[type]}</span>
        <div class="toast-content">
            <div class="toast-title">${esc(t(`toast_${type}`))}</div>
            <div class="toast-msg">${html}</div>
        </div>
        <button class="toast-close" type="button" aria-label="Fermer">${TOAST_ICONS.error}</button>
        <div class="toast-progress" style="animation-duration:${TOAST_DURATION}ms"></div>`;

    // La plus récente en haut, jamais plus de TOAST_MAX à l'écran
    els.toasts.prepend(el);
    [...els.toasts.children].slice(TOAST_MAX).forEach((old) => old.remove());

    let dismissed = false;
    const dismiss = () => {
        if (dismissed) return;
        dismissed = true;
        el.classList.add('leaving');
        setTimeout(() => el.remove(), 260);
    };

    // Disparition auto, en pause pendant le survol (la barre aussi)
    let remaining = TOAST_DURATION;
    let started = Date.now();
    let timer = setTimeout(dismiss, remaining);
    el.addEventListener('mouseenter', () => {
        clearTimeout(timer);
        remaining -= Date.now() - started;
    });
    el.addEventListener('mouseleave', () => {
        started = Date.now();
        timer = setTimeout(dismiss, Math.max(remaining, 800));
    });
    el.addEventListener('click', dismiss);
}

/* ---------- Réclamation ---------- */

function burst(card) {
    for (let i = 0; i < 14; i++) {
        const p = document.createElement('span');
        const angle = (Math.PI * 2 * i) / 14;
        const dist = 3 + Math.random() * 3;
        p.className = 'particle';
        p.style.setProperty('--x', `${Math.cos(angle) * dist}rem`);
        p.style.setProperty('--y', `${Math.sin(angle) * dist}rem`);
        card.appendChild(p);
        setTimeout(() => p.remove(), 850);
    }
}

async function claim() {
    if (claiming || !status || !status.canClaim) return;
    claiming = true;
    setClaimButton('loading');

    const res = await post('claim');
    if (res && res.message) toast(res.message, res.ok ? 'success' : 'error');

    if (res && res.ok) {
        const card = els.days.querySelector(`.day-card[data-day="${res.day}"]`);
        if (card) {
            card.classList.remove('state-current');
            card.classList.add('state-claimed', 'just-claimed');
            burst(card);
        }
        setClaimButton('success');

        setTimeout(() => {
            claiming = false;
            if (visible && res.status) render(res.status, { animate: false });
        }, 1200);
    } else {
        claiming = false;
        if (res && res.status) {
            render(res.status, { animate: false });
        } else {
            setClaimButton('idle');
            void els.claimBtn.offsetWidth; // relance l'animation
            els.claimBtn.classList.add('shake');
        }
    }
}

/* ---------- Pop-up d'incitation ---------- */

const POSITIONS = ['bottom-right', 'top-right', 'bottom-left', 'top-left'];

function showPopup({ status: s, key, command, duration, position }) {
    if (!s || visible) return;

    const rewards = asArray(s.rewards);
    const cycle = s.cycle || rewards.length;
    const day = s.nextDay;
    const r = parseReward(rewards[day - 1]);
    const big = day === cycle;
    const pos = POSITIONS.includes(position) ? position : 'bottom-right';

    els.popup.className = `popup pos-${pos} rarity-${r.rarity}`;
    els.popupDay.innerHTML = `${day}<small>/${cycle}</small>`;
    els.popupTag.textContent = t(big ? 'popup_tag_big' : 'popup_tag');

    // Ligne 1 : le montant (ou le premier item s'il n'y a pas d'argent)
    const firstItemInTitle = r.total <= 0 && r.items.length > 0;
    if (r.total > 0) {
        els.popupTitle.textContent = `${formatNumber(r.total)} ${t('currency')}`;
    } else if (firstItemInTitle) {
        els.popupTitle.textContent = `x${r.items[0].count} ${r.items[0].label}`;
    } else {
        els.popupTitle.textContent = t(`rarity_${r.rarity}`);
    }

    // Ligne 2 : rareté + bonus + items (ou série perdue)
    if (s.streakLost) {
        els.popupSub.innerHTML = `<span class="lost">${esc(t('popup_lost'))}</span>`;
    } else {
        const extras = [];
        const items = firstItemInTitle ? r.items.slice(1) : r.items;
        if (r.bonus) extras.push(esc(t('bonus')));
        if (items.length) {
            const more = items.length > 1 ? ` +${items.length - 1}` : '';
            extras.push(`x${items[0].count} ${esc(items[0].label)}${more}`);
        }
        els.popupSub.innerHTML = `<span class="rarity-label">${rarityHTML(r.rarity)}</span>`
            + (extras.length ? ` · ${extras.join(' · ')}` : '');
    }

    els.popupKey.textContent = key || `/${command}`;

    // Apparition (glisse depuis la droite)
    clearTimeout(popupTimer);
    els.popupTimer.classList.remove('running');
    void els.popup.offsetWidth;
    els.popup.classList.add('show');

    const seconds = Number(duration) || 0;
    els.popupTimer.classList.toggle('hidden', seconds <= 0);
    if (seconds > 0) {
        els.popup.style.setProperty('--duration', `${seconds}s`);
        els.popupTimer.classList.add('running');
        popupTimer = setTimeout(hidePopup, seconds * 1000);
    }
}

function hidePopup() {
    if (!els.popup.classList.contains('show')) return;
    clearTimeout(popupTimer);
    els.popup.classList.remove('show');
    popupTimer = setTimeout(() => els.popup.classList.add('hidden'), 650);
}

/* ---------- Ouverture / fermeture du menu ---------- */

function applyLocale() {
    document.querySelectorAll('[data-i18n]').forEach((el) => {
        el.textContent = t(el.dataset.i18n);
    });
}

function show() {
    clearTimeout(hideTimer);
    els.app.classList.remove('hidden');
    void els.app.offsetWidth; // force le reflow pour déclencher la transition
    els.app.classList.add('visible');
    visible = true;
}

function hide() {
    if (!visible) return;
    visible = false;
    stopCountdown();
    els.app.classList.remove('visible');
    hideTimer = setTimeout(() => els.app.classList.add('hidden'), 350);
}

// Fermeture côté UI : on rend le focus au jeu immédiatement
function requestClose() {
    if (!visible) return;
    hide();
    post('close');
}

window.addEventListener('message', ({ data }) => {
    if (!data || !data.action) return;

    switch (data.action) {
        case 'open':
            locale = data.locale || locale;
            applyLocale();
            hidePopup();
            claiming = false;
            render(data.status);
            show();
            break;
        case 'close':
            hide();
            break;
        case 'popup':
            locale = data.locale || locale;
            applyLocale();
            showPopup(data);
            break;
        case 'hidePopup':
            hidePopup();
            break;
        case 'toast':
            locale = data.locale || locale;
            toast(data.message, data.type);
            break;
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') requestClose();
});

els.closeBtn.addEventListener('click', requestClose);
els.claimBtn.addEventListener('click', claim);
