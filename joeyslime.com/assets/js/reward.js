(function () {
    const API_URL = 'https://api.joeyslime.com/info';
    const currentScript = document.currentScript;
    const scriptUrl = currentScript ? new URL(currentScript.src, window.location.href) : new URL(window.location.href);
    const siteRootUrl = new URL('../../', scriptUrl);
    const descriptionMap = {
        bat_artefact: 'Ein seltener Höhlenfund mit starkem Lore-Flair und hohem Sammlerwert.',
        golem_heart: 'Ein schwerer Kern aus uralter Magie, ideal für spätere Upgrades und große Builds.',
        gold_nugget: 'Eine wertige Nugget-Belohnung für stärkere Shop- und Fortschrittsläufe.',
        iron_nugget: 'Solides Material für frühe Aufwertungen und stabile Ressourcenrouten.',
        copper_nugget: 'Der häufigere Grundstoff für die frühe Ökonomie und erste Crafting-Schritte.',
        bat_claw: 'Ein schneller Drop aus Kapitel I, passend zu Joeys frühem Höhlen- und Gegnerfokus.',
    };

    function ready(fn) {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', fn, { once: true });
            return;
        }
        fn();
    }

    function assetUrl(itemName) {
        return new URL(`assets/media/${itemName}.png`, siteRootUrl).toString();
    }

    async function requestInfo() {
        const response = await fetch(API_URL, { cache: 'no-store' });
        const data = await response.json();
        if (!response.ok) {
            throw new Error(data.error || data.message || `Reward-API Fehler (${response.status})`);
        }
        return data;
    }

    function formatDate(value) {
        if (!value) {
            return 'Keine Daten';
        }

        return new Intl.DateTimeFormat('de-DE', {
            dateStyle: 'medium',
            timeStyle: 'short',
        }).format(new Date(value));
    }

    function formatCountdown(targetDate) {
        const diff = targetDate.getTime() - Date.now();
        if (diff <= 0) {
            return 'Jetzt';
        }

        const totalSeconds = Math.floor(diff / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        return `${String(hours).padStart(2, '0')}h ${String(minutes).padStart(2, '0')}m ${String(seconds).padStart(2, '0')}s`;
    }

    function rarityLabel(weight) {
        if (weight <= 1) {
            return 'Legendär';
        }
        if (weight <= 2) {
            return 'Selten';
        }
        if (weight <= 4) {
            return 'Ungewöhnlich';
        }
        return 'Häufig';
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    function updateText(id, value) {
        const element = document.getElementById(id);
        if (element) {
            element.textContent = value;
        }
    }

    function setStatusMessage(message, isError = false) {
        const element = document.getElementById('rewardLiveMessage');
        if (!element) {
            return;
        }
        element.textContent = message;
        element.classList.toggle('reward-status-error', isError);
        element.classList.toggle('reward-status-ok', !isError);
    }

    function renderCurrentItems(items, availableMap) {
        const grid = document.getElementById('rewardsGrid');
        if (!grid) {
            return;
        }

        if (!items || !items.length) {
            grid.innerHTML = '<div class="empty-state">Heute sind aktuell keine Rewards aktiv.</div>';
            updateText('rewardHeadline', 'Heute ist gerade kein Reward aktiv.');
            updateText('rewardTodaySummary', 'Kein aktiver Reward');
            return;
        }

        updateText('rewardHeadline', items.map((item) => item.displayName || item.item_name).join(' · '));
        updateText('rewardTodaySummary', items.map((item) => item.displayName || item.item_name).join(', '));

        grid.innerHTML = items
            .map((item) => {
                const meta = availableMap.get(item.item_name) || {};
                const rarity = rarityLabel(meta.rarityWeight || 5);
                const description = descriptionMap[item.item_name] || 'Eine tägliche Bonus-Belohnung für deinen nächsten Run.';
                return `
                    <article class="reward-card is-active scroll-reveal-stagger">
                        <div class="reward-card__image">
                            <img src="${assetUrl(item.item_name)}" alt="${escapeHtml(item.displayName || item.item_name)}" loading="lazy" onerror="this.onerror=null;this.src='${assetUrl('gold_nugget')}'">
                        </div>
                        <h3>${escapeHtml(item.displayName || item.item_name)}</h3>
                        <p>${escapeHtml(description)}</p>
                        <div class="reward-card__meta">
                            <span class="reward-tag reward-tag--accent">Heute aktiv</span>
                            <span class="reward-tag">${escapeHtml(rarity)}</span>
                            <span class="reward-tag">Gewicht ${escapeHtml(String(meta.rarityWeight || '—'))}</span>
                        </div>
                    </article>
                `;
            })
            .join('');

        if (typeof window.refreshScrollReveal === 'function') {
            window.refreshScrollReveal(grid);
        }
    }

    function renderPool(items, currentItemNames) {
        const grid = document.getElementById('rewardPoolGrid');
        if (!grid) {
            return;
        }

        if (!items || !items.length) {
            grid.innerHTML = '<div class="empty-state">Der Reward-Pool konnte nicht gelesen werden.</div>';
            return;
        }

        grid.innerHTML = items
            .map((item) => {
                const isActive = currentItemNames.has(item.name);
                const description = descriptionMap[item.name] || 'Teil des Daily-Reward-Pools.';
                return `
                    <article class="reward-pool-card ${isActive ? 'is-active' : ''} scroll-reveal-stagger">
                        <div class="reward-pool-card__image">
                            <img src="${assetUrl(item.name)}" alt="${escapeHtml(item.displayName || item.name)}" loading="lazy" onerror="this.onerror=null;this.src='${assetUrl('copper_nugget')}'">
                        </div>
                        <h3>${escapeHtml(item.displayName || item.name)}</h3>
                        <p>${escapeHtml(description)}</p>
                        <div class="reward-pool-card__meta">
                            <span class="reward-tag">${escapeHtml(rarityLabel(item.rarityWeight || 5))}</span>
                            <span class="reward-tag">Gewicht ${escapeHtml(String(item.rarityWeight || '—'))}</span>
                            ${isActive ? '<span class="reward-tag reward-tag--accent">Heute aktiv</span>' : ''}
                        </div>
                    </article>
                `;
            })
            .join('');

        if (typeof window.refreshScrollReveal === 'function') {
            window.refreshScrollReveal(grid);
        }
    }

    function initRewardPage() {
        if (!document.querySelector('[data-reward-root]')) {
            return;
        }

        let countdownTimer = null;

        requestInfo()
            .then((data) => {
                const availableItems = data.availableItems || [];
                const currentItems = data.currentItems || [];
                const availableMap = new Map(availableItems.map((item) => [item.name, item]));
                const currentItemNames = new Set(currentItems.map((item) => item.item_name));
                const lastReset = data.lastReset ? new Date(data.lastReset) : null;
                const nextReset = lastReset ? new Date(lastReset.getTime() + 24 * 60 * 60 * 1000) : null;

                renderCurrentItems(currentItems, availableMap);
                renderPool(availableItems, currentItemNames);

                updateText('rewardPoolSize', String(availableItems.length || 0));
                updateText('rewardLastReset', formatDate(data.lastReset));
                updateText('rewardServerVersion', data.serverVersion || 'Unbekannt');
                updateText(
                    'rewardPlayers',
                    Number(data.totalPlayers || 0) > 0
                        ? `${data.totalPlayers} Spieler wurden zuletzt erfasst`
                        : 'Noch keine Telemetrie gemeldet'
                );

                if (nextReset) {
                    updateText('rewardNextReset', formatDate(nextReset));
                    const updateCountdown = () => {
                        updateText('rewardCountdown', formatCountdown(nextReset));
                    };
                    updateCountdown();
                    countdownTimer = window.setInterval(updateCountdown, 1000);
                } else {
                    updateText('rewardNextReset', 'Keine Daten');
                    updateText('rewardCountdown', 'Keine Daten');
                }

                setStatusMessage('Reward-API verbunden. Die Live-Daten sind aktuell geladen.');
            })
            .catch((error) => {
                console.error('Reward API error:', error);
                const message = error.message || 'Die Reward-API konnte gerade nicht geladen werden.';
                updateText('rewardHeadline', 'Live-Daten gerade nicht verfügbar');
                updateText('rewardTodaySummary', 'Die API antwortet gerade nicht');
                updateText('rewardLastReset', 'Nicht verfügbar');
                updateText('rewardNextReset', 'Nicht verfügbar');
                updateText('rewardCountdown', 'Nicht verfügbar');
                updateText('rewardPlayers', 'Nicht verfügbar');
                updateText('rewardServerVersion', 'Nicht verfügbar');
                setStatusMessage(message, true);

                const rewardsGrid = document.getElementById('rewardsGrid');
                const rewardPoolGrid = document.getElementById('rewardPoolGrid');
                if (rewardsGrid) {
                    rewardsGrid.innerHTML = '<div class="empty-state">Die heutigen Rewards konnten gerade nicht geladen werden.</div>';
                }
                if (rewardPoolGrid) {
                    rewardPoolGrid.innerHTML = '<div class="empty-state">Der Reward-Pool konnte gerade nicht geladen werden.</div>';
                }
            });

        window.addEventListener(
            'beforeunload',
            () => {
                if (countdownTimer) {
                    window.clearInterval(countdownTimer);
                }
            },
            { once: true }
        );
    }

    ready(initRewardPage);
})();
