(function () {
    const LIKE_MESSAGE_TIMEOUT = 3000;
    const storageFallback = new Map();
    const currentScript = document.currentScript;
    const scriptUrl = currentScript ? new URL(currentScript.src, window.location.href) : new URL(window.location.href);
    const siteRootUrl = new URL('../../', scriptUrl);
    let scrollRevealObserver = null;
    const communityState = {
        currentPage: 1,
        commentsPerPage: 10,
        likeRequestInFlight: false,
        currentFilter: 'all',
    };

    function ready(fn) {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', fn, { once: true });
            return;
        }
        fn();
    }

    function safeStorageGet(key) {
        try {
            return window.localStorage.getItem(key);
        } catch (error) {
            return storageFallback.has(key) ? storageFallback.get(key) : null;
        }
    }

    function safeStorageSet(key, value) {
        try {
            window.localStorage.setItem(key, value);
        } catch (error) {
            storageFallback.set(key, String(value));
        }
    }

    async function requestJson(url, options = {}) {
        const response = await fetch(url, {
            cache: 'no-store',
            ...options,
        });
        const rawText = await response.text();
        let data = {};

        if (rawText) {
            try {
                data = JSON.parse(rawText);
            } catch (error) {
                throw new Error('Ungültige Antwort vom Server');
            }
        }

        if (!response.ok) {
            throw new Error(data.error || data.message || `Serverfehler (${response.status})`);
        }

        return data;
    }

    function siteUrl(relativePath) {
        return new URL(relativePath.replace(/^\/+/, ''), siteRootUrl).toString();
    }

    function getUserId() {
        let userId = safeStorageGet('slimeventure_userId');
        if (!userId) {
            userId = 'user_' + Math.random().toString(36).slice(2, 11);
            safeStorageSet('slimeventure_userId', userId);
        }
        return userId;
    }

    function normalizePath(input) {
        try {
            const url = new URL(input, window.location.origin);
            let pathname = url.pathname.replace(/index\.html$/, '');
            if (!pathname.endsWith('/')) {
                pathname += '/';
            }
            return pathname || '/';
        } catch (error) {
            return '/';
        }
    }

    function initLoadingBar() {
        const bar = document.getElementById('loadingBar');
        if (!bar) {
            return;
        }

        bar.style.width = '35%';
        window.setTimeout(() => {
            bar.style.width = '100%';
            window.setTimeout(() => {
                bar.style.opacity = '0';
            }, 280);
        }, 80);
    }

    function initNav() {
        const nav = document.querySelector('.main-nav');
        const navLinks = document.querySelector('.nav-links');
        const hamburger = document.getElementById('hamburger-menu');
        const currentPath = normalizePath(window.location.pathname);

        document.querySelectorAll('.nav-links a').forEach((link) => {
            if (normalizePath(link.href) === currentPath) {
                link.classList.add('active');
            }
        });

        if (hamburger && navLinks) {
            const closeMenu = () => {
                hamburger.classList.remove('active');
                hamburger.setAttribute('aria-expanded', 'false');
                navLinks.classList.remove('active');
            };

            const openMenu = () => {
                hamburger.classList.add('active');
                hamburger.setAttribute('aria-expanded', 'true');
                navLinks.classList.add('active');
            };

            hamburger.addEventListener('click', () => {
                if (navLinks.classList.contains('active')) {
                    closeMenu();
                } else {
                    openMenu();
                }
            });

            navLinks.querySelectorAll('a').forEach((link) => {
                link.addEventListener('click', () => {
                    closeMenu();
                });
            });

            document.addEventListener('click', (event) => {
                if (!nav.contains(event.target)) {
                    closeMenu();
                }
            });

            document.addEventListener('keydown', (event) => {
                if (event.key === 'Escape') {
                    closeMenu();
                }
            });
        }

        const onScroll = () => {
            if (!nav) {
                return;
            }
            nav.classList.toggle('scrolled', window.scrollY > 20);
        };

        onScroll();
        window.addEventListener('scroll', onScroll, { passive: true });
    }

    function normalizeFileSchemeLinks() {
        if (window.location.protocol !== 'file:') {
            return;
        }

        document.querySelectorAll('a[href]').forEach((link) => {
            const rawHref = link.getAttribute('href');
            if (!rawHref) {
                return;
            }

            if (/^(?:[a-z]+:|#|\/\/)/i.test(rawHref)) {
                return;
            }

            if (rawHref.endsWith('/') || rawHref === '.' || rawHref === '..' || rawHref.endsWith('/.')) {
                const normalizedBase = rawHref.replace(/\/?$/, '/');
                link.setAttribute('href', `${normalizedBase}index.html`);
            }
        });
    }

    function initScrollReveal() {
        if (!scrollRevealObserver) {
            scrollRevealObserver = new IntersectionObserver(
                (entries) => {
                    entries.forEach((entry) => {
                        if (entry.isIntersecting) {
                            entry.target.classList.add('revealed');
                            scrollRevealObserver.unobserve(entry.target);
                        }
                    });
                },
                { threshold: 0.14, rootMargin: '0px 0px -30px 0px' }
            );
        }

        const refresh = (root = document) => {
            const animated = root.querySelectorAll(
                '.scroll-reveal, .scroll-reveal-left, .scroll-reveal-right, .scroll-reveal-scale, .scroll-reveal-stagger'
            );

            animated.forEach((element) => {
                if (!element.classList.contains('revealed')) {
                    scrollRevealObserver.observe(element);
                }
            });
        };

        window.refreshScrollReveal = refresh;
        refresh(document);

        if (!document.querySelector(
            '.scroll-reveal, .scroll-reveal-left, .scroll-reveal-right, .scroll-reveal-scale, .scroll-reveal-stagger'
        )) {
            return;
        }
    }

    function initScrollFloat() {
        const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        if (reducedMotion || window.innerWidth < 768) {
            return;
        }

        const headings = Array.from(document.querySelectorAll('.hero h1, .section-header h2'));
        if (!headings.length) {
            return;
        }

        const observer = new IntersectionObserver(
            (entries) => {
                entries.forEach((entry) => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('scroll-float-visible');
                        observer.unobserve(entry.target);
                    }
                });
            },
            { threshold: 0.3, rootMargin: '0px 0px -12% 0px' }
        );

        headings.forEach((heading) => {
            if (heading.dataset.scrollFloatReady === 'true') {
                return;
            }

            const text = (heading.textContent || '').trim();
            if (!text) {
                return;
            }

            heading.dataset.scrollFloatReady = 'true';
            heading.classList.add('scroll-float-target');
            heading.setAttribute('aria-label', text);
            heading.textContent = '';

            const textWrapper = document.createElement('span');
            textWrapper.className = 'scroll-float-text';
            textWrapper.setAttribute('aria-hidden', 'true');

            Array.from(text).forEach((char, index) => {
                const span = document.createElement('span');
                span.className = 'scroll-float-char';
                span.style.setProperty('--float-index', index);
                span.textContent = char === ' ' ? '\u00A0' : char;
                textWrapper.appendChild(span);
            });

            heading.appendChild(textWrapper);
            observer.observe(heading);
        });
    }

    function initBackToTop() {
        const button = document.getElementById('backToTop');
        if (!button) {
            return;
        }

        const onScroll = () => {
            button.classList.toggle('visible', window.scrollY > 450);
        };

        onScroll();
        window.addEventListener('scroll', onScroll, { passive: true });
        button.addEventListener('click', () => {
            window.scrollTo({ top: 0, behavior: 'smooth' });
        });
    }

    function initDevlogFilters() {
        const root = document.querySelector('[data-devlog-root]');
        if (!root) {
            return;
        }

        const searchInput = document.getElementById('devlogSearch');
        const buttons = Array.from(document.querySelectorAll('[data-filter]'));
        const entries = Array.from(document.querySelectorAll('[data-devlog-entry]'));
        const empty = document.getElementById('devlogEmpty');

        const applyFilter = () => {
            const term = (searchInput?.value || '').trim().toLowerCase();
            const category = communityState.currentFilter;
            let visibleCount = 0;

            entries.forEach((entry) => {
                const matchesCategory = category === 'all' || entry.dataset.category === category;
                const haystack = (entry.dataset.search || '').toLowerCase();
                const matchesTerm = !term || haystack.includes(term);
                const visible = matchesCategory && matchesTerm;
                entry.hidden = !visible;
                if (visible) {
                    visibleCount += 1;
                }
            });

            if (empty) {
                empty.hidden = visibleCount > 0;
            }
        };

        if (searchInput) {
            searchInput.addEventListener('input', applyFilter);
        }

        buttons.forEach((button) => {
            button.addEventListener('click', () => {
                communityState.currentFilter = button.dataset.filter || 'all';
                buttons.forEach((candidate) => candidate.classList.remove('active'));
                button.classList.add('active');
                applyFilter();
            });
        });

        applyFilter();
    }

    async function initWikiSearch() {
        const input = document.getElementById('wikiSearchInput');
        const output = document.getElementById('wikiSearchResults');
        if (!input || !output) {
            return;
        }

        let entries = [];

        try {
            const payload = await requestJson(siteUrl('assets/data/search-index.json'));
            entries = payload.entries || [];
        } catch (error) {
            output.innerHTML = '<div class="empty-state">Der Suchindex konnte gerade nicht geladen werden.</div>';
            return;
        }

        const render = () => {
            const term = input.value.trim().toLowerCase();
            const matches = entries
                .filter((entry) => {
                    if (!term) {
                        return false;
                    }
                    const haystack = [entry.title, entry.summary, ...(entry.tags || [])].join(' ').toLowerCase();
                    return haystack.includes(term);
                })
                .slice(0, 8);

            if (!term) {
                output.innerHTML = '<div class="empty-state">Suchbegriffe wie “Glow”, “Bat”, “Items” oder “Kapitel” liefern dir direkte Seiten und Wiki-Einstiege.</div>';
                return;
            }

            if (!matches.length) {
                output.innerHTML = '<div class="empty-state">Keine Treffer im Suchindex gefunden.</div>';
                return;
            }

            output.innerHTML = matches
                .map(
                    (entry) => `
                    <a class="result-item" href="${entry.path}">
                        <strong>${escapeHtml(entry.title)}</strong>
                        <span>${escapeHtml(entry.summary)}</span>
                    </a>
                `
                )
                .join('');
        };

        input.addEventListener('input', render);
        render();
    }

    function initQuickFinder() {
        const openButton = document.getElementById('quickFinderOpen');
        const modal = document.getElementById('siteCommand');
        const input = document.getElementById('siteCommandInput');
        const output = document.getElementById('siteCommandResults');

        if (!openButton || !modal || !input || !output) {
            return;
        }

        const manualItems = [
            {
                title: 'Demo spielen',
                meta: 'Start',
                description: 'Direkt in die Browser-Demo springen und Joey sofort selbst ausprobieren.',
                href: siteUrl('web_demo/index.html'),
                tags: ['demo', 'spielen', 'browser', 'start'],
                featured: true,
            },
            {
                title: 'Spielüberblick',
                meta: 'Spiel',
                description: 'Plattformen, Controls, Features und Roadmap ohne langes Suchen.',
                href: siteUrl('play/index.html'),
                tags: ['spiel', 'controls', 'roadmap', 'features'],
                featured: true,
            },
            {
                title: 'Welt & Kapitel',
                meta: 'Welt',
                description: 'Story, Biome, Kapitelstruktur und Progression vom Hub aus.',
                href: siteUrl('world/index.html'),
                tags: ['welt', 'kapitel', 'story', 'biome', 'progression'],
                featured: true,
            },
            {
                title: 'Game Wiki',
                meta: 'Wiki',
                description: 'Mechaniken, Gegner, Items und Freischaltungen strukturiert nachlesen.',
                href: siteUrl('wiki/index.html'),
                tags: ['wiki', 'mechaniken', 'gegner', 'items', 'skills'],
                featured: true,
            },
            {
                title: 'Git-Devlog',
                meta: 'Devlog',
                description: 'Echte Projektfortschritte direkt aus dem Git-Verlauf verfolgen.',
                href: siteUrl('devlog/index.html'),
                tags: ['devlog', 'git', 'updates', 'changelog'],
                featured: true,
            },
            {
                title: 'Media & Press',
                meta: 'Media',
                description: 'Screens, Fakten, Kontakt und offizielle Pressematerialien.',
                href: siteUrl('media/index.html'),
                tags: ['media', 'press', 'screenshots', 'presse'],
            },
            {
                title: 'Daily Rewards',
                meta: 'Rewards',
                description: 'Heute aktive Belohnungen, Reset-Zeiten und Reward-Pool prüfen.',
                href: siteUrl('reward/index.html'),
                tags: ['rewards', 'daily', 'belohnung', 'reset'],
            },
            {
                title: 'FAQ',
                meta: 'Support',
                description: 'Schnelle Antworten auf Demo, Plattformen, Progression und Website-Fragen.',
                href: siteUrl('faq/index.html'),
                tags: ['faq', 'hilfe', 'support', 'fragen'],
            },
            {
                title: 'GitHub',
                meta: 'Offiziell',
                description: 'Repository, Entwicklung und offizielle Projektbasis ansehen.',
                href: 'https://github.com/JoshuaPondStudios/JoeysSlimeventure',
                external: true,
                tags: ['github', 'git', 'repository', 'code'],
            },
            {
                title: 'TikTok',
                meta: 'Social',
                description: 'Kurzclips, Updates und Spielmomente auf TikTok verfolgen.',
                href: 'https://www.tiktok.com/@joeysslimeventure',
                external: true,
                tags: ['tiktok', 'social', 'clips', 'video'],
            },
            {
                title: 'YouTube',
                meta: 'Social',
                description: 'Trailer, Dev-Videos und längere Einblicke über PondSec.',
                href: 'https://youtube.com/@pondsec',
                external: true,
                tags: ['youtube', 'trailer', 'video', 'pondsec'],
            },
        ];
        const crawlTargets = [
            { href: siteUrl('index.html'), meta: 'Start' },
            { href: siteUrl('play/index.html'), meta: 'Spiel' },
            { href: siteUrl('world/index.html'), meta: 'Welt' },
            { href: siteUrl('devlog/index.html'), meta: 'Devlog' },
            { href: siteUrl('wiki/index.html'), meta: 'Wiki' },
            { href: siteUrl('wiki/mechanics/index.html'), meta: 'Mechaniken' },
            { href: siteUrl('wiki/enemies/index.html'), meta: 'Gegner' },
            { href: siteUrl('wiki/items/index.html'), meta: 'Items' },
            { href: siteUrl('wiki/progression/index.html'), meta: 'Progression' },
            { href: siteUrl('media/index.html'), meta: 'Media' },
            { href: siteUrl('reward/index.html'), meta: 'Rewards' },
            { href: siteUrl('about/index.html'), meta: 'Entwickler' },
            { href: siteUrl('faq/index.html'), meta: 'FAQ' },
        ];

        let lastFocusedElement = null;
        let items = [];
        let indexReady = false;
        let indexFailed = false;
        let loadPromise = null;
        const header = modal.querySelector('.site-command__header');
        const backdrop = modal.querySelector('.site-command__backdrop');
        const panel = modal.querySelector('.site-command__panel');

        const compactText = (value) => String(value || '').replace(/\s+/g, ' ').trim();
        const normalizeSearchValue = (value) =>
            compactText(value)
                .toLowerCase()
                .normalize('NFD')
                .replace(/[\u0300-\u036f]/g, '')
                .replace(/ß/g, 'ss');
        const uniqueStrings = (values) => {
            const seen = new Set();
            const result = [];

            values.forEach((value) => {
                const text = compactText(value);
                if (!text) {
                    return;
                }

                const key = normalizeSearchValue(text);
                if (seen.has(key)) {
                    return;
                }

                seen.add(key);
                result.push(text);
            });

            return result;
        };
        const trimSearchText = (value, maxLength = 4800) => {
            const text = compactText(value);
            if (text.length <= maxLength) {
                return text;
            }
            return `${text.slice(0, maxLength)}...`;
        };
        const applyQuickFinderFallbackStyles = () => {
            const modalStyle = window.getComputedStyle(modal);

            if (modalStyle.position !== 'fixed') {
                Object.assign(modal.style, {
                    position: 'fixed',
                    top: '0',
                    right: '0',
                    bottom: '0',
                    left: '0',
                    zIndex: '1300',
                    display: 'flex',
                    justifyContent: 'center',
                    alignItems: 'flex-start',
                    padding: '110px 24px 24px',
                });
            }

            if (backdrop && window.getComputedStyle(backdrop).position !== 'absolute') {
                Object.assign(backdrop.style, {
                    position: 'absolute',
                    top: '0',
                    right: '0',
                    bottom: '0',
                    left: '0',
                    border: 'none',
                    background: 'rgba(0, 0, 0, 0.72)',
                });
            }

            if (panel) {
                const panelStyle = window.getComputedStyle(panel);
                if (panelStyle.display !== 'grid' || panelStyle.borderTopWidth === '0px') {
                    Object.assign(panel.style, {
                        position: 'relative',
                        width: 'min(760px, 100%)',
                        maxWidth: '760px',
                        padding: '24px',
                        border: '3px solid var(--primary-dark)',
                        borderRadius: '10px',
                        background: 'rgba(10, 10, 10, 0.98)',
                        boxShadow: '10px 10px 0 rgba(0, 0, 0, 0.35)',
                        display: 'grid',
                        gap: '16px',
                        zIndex: '1',
                    });
                }
            }

            if (header) {
                const headerStyle = window.getComputedStyle(header);
                if (headerStyle.display !== 'flex') {
                    Object.assign(header.style, {
                        display: 'flex',
                        alignItems: 'flex-start',
                        justifyContent: 'space-between',
                        gap: '16px',
                    });
                }
            }

            output.querySelectorAll('a').forEach((link) => {
                const linkStyle = window.getComputedStyle(link);
                if (linkStyle.display !== 'block' || linkStyle.borderTopWidth === '0px') {
                    Object.assign(link.style, {
                        display: 'block',
                        textDecoration: 'none',
                        color: 'var(--light)',
                        padding: '16px 18px',
                        borderRadius: '10px',
                        border: '2px solid rgba(76, 175, 80, 0.72)',
                        background: 'rgba(22, 22, 22, 0.88)',
                        boxShadow: '4px 4px 0 rgba(0, 0, 0, 0.22)',
                    });
                }

                const title = link.querySelector('.site-command__item-title');
                if (title) {
                    Object.assign(title.style, {
                        display: 'block',
                        color: 'var(--primary)',
                        fontSize: '0.76rem',
                        marginBottom: '8px',
                    });
                }

                const meta = link.querySelector('.site-command__item-meta');
                if (meta) {
                    Object.assign(meta.style, {
                        display: 'block',
                        color: 'var(--accent)',
                        fontSize: '0.58rem',
                        marginBottom: '8px',
                    });
                }

                const description = link.querySelector('.site-command__item-description');
                if (description) {
                    Object.assign(description.style, {
                        display: 'block',
                        color: 'var(--text-secondary)',
                        fontSize: '0.68rem',
                        lineHeight: '1.7',
                    });
                }
            });
        };
        const createSearchEntry = (item, order = 0) => {
            const title = compactText(item.title || 'Seite');
            const meta = compactText(item.meta || 'Website');
            const description = compactText(item.description || 'Inhalt auf joeyslime.com');
            const href = compactText(item.href || siteUrl('index.html'));
            const tags = uniqueStrings(item.tags || []);
            const searchText = trimSearchText(item.searchText || '');
            const searchParts = uniqueStrings([title, meta, description, href, ...tags, searchText]);

            return {
                title,
                meta,
                description,
                href,
                tags,
                external: Boolean(item.external),
                featured: Boolean(item.featured),
                searchText,
                _order: order,
                _titleNorm: normalizeSearchValue(title),
                _metaNorm: normalizeSearchValue(meta),
                _descriptionNorm: normalizeSearchValue(description),
                _hrefNorm: normalizeSearchValue(href),
                _tagsNorm: tags.map((tag) => normalizeSearchValue(tag)),
                _searchBlob: normalizeSearchValue(searchParts.join(' ')),
            };
        };
        const mergeSearchItems = (entryGroups) => {
            const merged = new Map();

            entryGroups.flat().forEach((entry) => {
                const prepared = createSearchEntry(entry, merged.size);
                const key = `${prepared.href}::${prepared._titleNorm}`;
                const existing = merged.get(key);

                if (!existing) {
                    merged.set(key, prepared);
                    return;
                }

                existing.tags = uniqueStrings([...existing.tags, ...prepared.tags]);
                existing.searchText = trimSearchText([existing.searchText, prepared.searchText].join(' '));
                existing.description =
                    existing.description.length >= prepared.description.length ? existing.description : prepared.description;
                existing.featured = existing.featured || prepared.featured;
                existing.external = existing.external || prepared.external;
                existing._tagsNorm = existing.tags.map((tag) => normalizeSearchValue(tag));
                existing._descriptionNorm = normalizeSearchValue(existing.description);
                existing._searchBlob = normalizeSearchValue(
                    uniqueStrings([existing.title, existing.meta, existing.description, existing.href, ...existing.tags, existing.searchText]).join(' ')
                );
            });

            return Array.from(merged.values()).map((entry, index) => ({ ...entry, _order: index }));
        };
        const snippetFromText = (text, fallback = 'Direkter Einstieg auf joeyslime.com.') => {
            const compact = compactText(text);
            if (!compact) {
                return fallback;
            }
            if (compact.length <= 180) {
                return compact;
            }
            return `${compact.slice(0, 177)}...`;
        };
        const extractSearchableText = (root) => {
            if (!root) {
                return '';
            }

            const clone = root.cloneNode(true);
            clone.querySelectorAll('script, style, noscript, template').forEach((node) => node.remove());

            const parts = Array.from(
                clone.querySelectorAll('h1, h2, h3, h4, p, li, summary, dt, dd, figcaption, strong, .pill, .eyebrow, a[href]')
            )
                .map((node) => compactText(node.textContent))
                .filter(Boolean);

            return trimSearchText(uniqueStrings(parts).join(' '));
        };
        const parseDocumentEntries = (doc, href, fallbackMeta) => {
            const main = doc.querySelector('main') || doc.body;
            if (!main) {
                return [];
            }

            const metaTitle = doc.querySelector('meta[property="og:title"]')?.getAttribute('content');
            const metaDescription = doc.querySelector('meta[name="description"]')?.getAttribute('content');
            const pageTitle = compactText(metaTitle || doc.title || fallbackMeta || 'Seite');
            const pageText = extractSearchableText(main);
            const pageDescription = compactText(metaDescription) || snippetFromText(pageText);
            const pageLinks = Array.from(main.querySelectorAll('a[href]'))
                .map((link) => compactText(link.textContent))
                .filter(Boolean)
                .slice(0, 24);

            const pageEntry = {
                title: pageTitle,
                meta: fallbackMeta || 'Website',
                description: pageDescription,
                href,
                tags: pageLinks,
                searchText: pageText,
            };
            const sectionEntries = Array.from(
                main.querySelectorAll('section, article, details, .content-panel, .feature-card, .stat-card, .timeline-entry, .faq-item, .media-tile, .link-card')
            )
                .slice(0, 18)
                .map((section) => {
                    const heading = section.querySelector('h2, h3, summary');
                    const title = compactText(heading?.textContent);
                    const searchText = extractSearchableText(section);

                    if (!title || !searchText) {
                        return null;
                    }

                    const anchor = heading?.id ? `#${heading.id}` : '';
                    return {
                        title,
                        meta: pageTitle,
                        description: snippetFromText(searchText, pageDescription),
                        href: `${href}${anchor}`,
                        tags: [fallbackMeta, pageTitle],
                        searchText,
                    };
                })
                .filter(Boolean);

            return [pageEntry, ...sectionEntries];
        };
        const loadStructuredIndex = async () => {
            try {
                const response = await fetch(siteUrl('assets/data/search-index.json'), { cache: 'no-store' });
                if (!response.ok) {
                    throw new Error(`Suchindex konnte nicht geladen werden (${response.status})`);
                }

                const data = await response.json();
                return (data.entries || []).map((entry) => ({
                    title: entry.title,
                    meta: entry.path === '/' ? 'Start' : entry.path.replace(/^\/|\/$/g, '') || 'Website',
                    description: entry.summary,
                    href: siteUrl(entry.path),
                    tags: entry.tags || [],
                    searchText: [entry.summary, ...(entry.tags || [])].join(' '),
                }));
            } catch (error) {
                console.error('Quick finder structured index failed:', error);
                return [];
            }
        };
        const loadPageEntries = async () => {
            const currentPath = normalizePath(window.location.pathname);
            const pages = await Promise.allSettled(
                crawlTargets.map(async (target) => {
                    const targetPath = normalizePath(target.href);

                    if (targetPath === currentPath) {
                        return parseDocumentEntries(document, target.href, target.meta);
                    }

                    const response = await fetch(target.href, { cache: 'force-cache' });
                    if (!response.ok) {
                        throw new Error(`Page fetch failed for ${target.href}`);
                    }

                    const html = await response.text();
                    const parsed = new DOMParser().parseFromString(html, 'text/html');
                    return parseDocumentEntries(parsed, target.href, target.meta);
                })
            );

            return pages.flatMap((result) => (result.status === 'fulfilled' ? result.value : []));
        };
        const ensureIndexLoaded = () => {
            if (loadPromise) {
                return loadPromise;
            }

            loadPromise = Promise.all([loadStructuredIndex(), loadPageEntries()])
                .then(([structuredItems, pageItems]) => {
                    items = mergeSearchItems([manualItems, structuredItems, pageItems]);
                    indexReady = true;
                    indexFailed = false;
                    render();
                })
                .catch((error) => {
                    console.error('Quick finder full index failed:', error);
                    items = mergeSearchItems([manualItems]);
                    indexReady = true;
                    indexFailed = true;
                    render();
                });

            return loadPromise;
        };

        const isTypingTarget = (target) => {
            if (!target) {
                return false;
            }

            const tagName = target.tagName ? target.tagName.toLowerCase() : '';
            return tagName === 'input' || tagName === 'textarea' || target.isContentEditable;
        };
        const scoreItem = (item, normalizedTerm, termTokens) => {
            if (!normalizedTerm) {
                return item.featured ? 1000 - item._order : 100 - item._order;
            }

            if (!termTokens.every((token) => item._searchBlob.includes(token))) {
                return -1;
            }

            let score = 0;

            if (item._titleNorm === normalizedTerm) {
                score += 600;
            }
            if (item._titleNorm.startsWith(normalizedTerm)) {
                score += 280;
            } else if (item._titleNorm.includes(normalizedTerm)) {
                score += 180;
            }
            if (item._metaNorm.includes(normalizedTerm)) {
                score += 90;
            }
            if (item._descriptionNorm.includes(normalizedTerm)) {
                score += 70;
            }
            if (item._hrefNorm.includes(normalizedTerm)) {
                score += 50;
            }

            termTokens.forEach((token) => {
                if (item._titleNorm.startsWith(token)) {
                    score += 90;
                } else if (item._titleNorm.includes(token)) {
                    score += 55;
                }

                if (item._metaNorm.includes(token)) {
                    score += 28;
                }
                if (item._descriptionNorm.includes(token)) {
                    score += 22;
                }
                if (item._hrefNorm.includes(token)) {
                    score += 16;
                }
                if (item._tagsNorm.some((tag) => tag.includes(token))) {
                    score += 18;
                }
            });

            if (item.featured) {
                score += 12;
            }

            return score - item._order * 0.01;
        };

        const render = () => {
            const term = compactText(input.value);
            const normalizedTerm = normalizeSearchValue(term);
            const termTokens = normalizedTerm.split(/\s+/).filter(Boolean);

            if (!normalizedTerm && !indexReady) {
                output.innerHTML =
                    '<div class="site-command__empty">Indexiere gerade Spiel, Welt, Wiki, Devlog, Media und FAQ fuer eine deutlich tiefere Suche...</div>';
                return;
            }

            const matches = items
                .map((item) => ({ item, score: scoreItem(item, normalizedTerm, termTokens) }))
                .filter((entry) => entry.score >= 0)
                .sort((left, right) => right.score - left.score)
                .map((entry) => entry.item)
                .slice(0, normalizedTerm ? 12 : 10);

            if (!matches.length) {
                const fallbackMessage = indexFailed
                    ? 'Keine Treffer. Der erweiterte Index war gerade nicht verfuegbar, daher lief nur die Kurzsuche.'
                    : 'Keine Treffer. Probiere Begriffe aus Inhalten, Gegnern, Items, Skills, Story, FAQ oder Devlog.';
                output.innerHTML = `<div class="site-command__empty">${fallbackMessage}</div>`;
                return;
            }

            output.innerHTML = matches
                .map((item) => {
                    const attrs = item.external ? ' target="_blank" rel="noreferrer"' : '';
                    return `
                        <a class="site-command__item" href="${item.href}"${attrs}>
                            <strong class="site-command__item-title">${escapeHtml(item.title)}</strong>
                            <span class="site-command__item-meta">${escapeHtml(item.meta)}</span>
                            <span class="site-command__item-description">${escapeHtml(item.description)}</span>
                        </a>
                    `;
                })
                .join('\n');
            applyQuickFinderFallbackStyles();
        };

        const close = () => {
            if (modal.hidden) {
                return;
            }
            modal.hidden = true;
            modal.setAttribute('aria-hidden', 'true');
            document.body.classList.remove('command-open');
            if (lastFocusedElement && typeof lastFocusedElement.focus === 'function') {
                lastFocusedElement.focus();
            }
        };

        const open = () => {
            lastFocusedElement = document.activeElement;
            modal.hidden = false;
            modal.setAttribute('aria-hidden', 'false');
            document.body.classList.add('command-open');
            input.value = '';
            render();
            applyQuickFinderFallbackStyles();
            window.setTimeout(() => input.focus(), 20);
            ensureIndexLoaded();
        };

        openButton.addEventListener('click', open);
        openButton.title = 'Schnellfinder öffnen';

        modal.querySelectorAll('[data-command-close]').forEach((button) => {
            button.addEventListener('click', close);
        });

        input.addEventListener('input', render);
        output.addEventListener('click', (event) => {
            const link = event.target.closest('a');
            if (link) {
                close();
            }
        });

        document.addEventListener('keydown', (event) => {
            const shortcutPressed = (event.key.toLowerCase() === 'k' && (event.metaKey || event.ctrlKey));
            const slashPressed = event.key === '/' && !isTypingTarget(event.target);

            if (shortcutPressed || slashPressed) {
                event.preventDefault();
                open();
                return;
            }

            if (event.key === 'Escape') {
                close();
            }
        });

        items = mergeSearchItems([manualItems]);
        render();

        if ('requestIdleCallback' in window) {
            window.requestIdleCallback(() => ensureIndexLoaded(), { timeout: 1200 });
        } else {
            window.setTimeout(() => ensureIndexLoaded(), 250);
        }
    }

    function initSocialLoopFallback() {
        document.querySelectorAll('.social-loop').forEach((loop) => {
            const items = Array.from(loop.querySelectorAll('.social-loop__item'));
            if (!items.length) {
                return;
            }

            const needsFallback = items.some((item) => {
                const style = window.getComputedStyle(item);
                return style.display === 'inline' || style.borderTopWidth === '0px';
            });

            if (!needsFallback) {
                return;
            }

            const track = loop.querySelector('.social-loop__track');
            const primaryGroup = loop.querySelector('.social-loop__group');
            const mirroredGroup = loop.querySelector('.social-loop__group[aria-hidden="true"]');

            if (track) {
                Object.assign(track.style, {
                    display: 'block',
                    width: '100%',
                    animation: 'none',
                    transform: 'none',
                });
            }

            if (mirroredGroup) {
                mirroredGroup.hidden = true;
            }

            if (primaryGroup) {
                Object.assign(primaryGroup.style, {
                    display: 'flex',
                    alignItems: 'center',
                    flexWrap: 'wrap',
                    gap: '14px',
                    paddingLeft: '18px',
                    paddingRight: '18px',
                });
            }

            items.forEach((item) => {
                Object.assign(item.style, {
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '10px',
                    minHeight: '48px',
                    padding: '12px 16px',
                    border: '2px solid rgba(76, 175, 80, 0.76)',
                    borderRadius: '8px',
                    background: 'rgba(22, 22, 22, 0.92)',
                    color: 'var(--light)',
                    textDecoration: 'none',
                    fontSize: '0.72rem',
                    whiteSpace: 'nowrap',
                    boxShadow: '4px 4px 0 rgba(0, 0, 0, 0.2)',
                });

                const icon = item.querySelector('i');
                if (icon) {
                    Object.assign(icon.style, {
                        color: 'var(--primary)',
                        fontSize: '0.92rem',
                    });
                }
            });
        });
    }

    function setLikeMessage(message, isError = false) {
        const target = document.getElementById('likeMessage');
        if (!target) {
            return;
        }

        target.textContent = message || '';
        target.style.color = isError ? 'var(--accent)' : '';
        window.clearTimeout(setLikeMessage.timeoutId);

        if (message) {
            setLikeMessage.timeoutId = window.setTimeout(() => {
                target.textContent = '';
                target.style.color = '';
            }, LIKE_MESSAGE_TIMEOUT);
        }
    }

    async function loadLikes() {
        const totalLikes = document.getElementById('totalLikes');
        const likeBtn = document.getElementById('likeBtn');
        if (!totalLikes || !likeBtn) {
            return;
        }

        try {
            const data = await requestJson('https://api.joeyslime.com/api/likes');
            const userId = getUserId();
            totalLikes.textContent = data.likes ?? 0;
            likeBtn.classList.toggle('liked', Boolean(data.userLikes && data.userLikes[userId]));
        } catch (error) {
            console.error('Error loading likes:', error);
            setLikeMessage('Likes konnten gerade nicht geladen werden.', true);
        }
    }

    async function toggleLike() {
        const likeBtn = document.getElementById('likeBtn');
        if (!likeBtn || communityState.likeRequestInFlight) {
            return;
        }

        const isUnlike = likeBtn.classList.contains('liked');
        const endpoint = isUnlike ? '/api/unlike' : '/api/like';

        try {
            communityState.likeRequestInFlight = true;
            likeBtn.disabled = true;
            likeBtn.setAttribute('aria-busy', 'true');

            const data = await requestJson(`https://api.joeyslime.com${endpoint}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ userId: getUserId() }),
            });

            if (!data.success) {
                throw new Error(data.error || data.message || 'Like konnte nicht gespeichert werden');
            }

            likeBtn.classList.toggle('liked', !isUnlike);
            const totalLikes = document.getElementById('totalLikes');
            if (totalLikes) {
                totalLikes.textContent = data.likes ?? 0;
            }
            setLikeMessage(data.message || (isUnlike ? 'Like entfernt.' : 'Danke für dein Like!'));
        } catch (error) {
            console.error('Error toggling like:', error);
            setLikeMessage(error.message || 'Fehler beim Senden des Likes', true);
        } finally {
            communityState.likeRequestInFlight = false;
            likeBtn.disabled = false;
            likeBtn.removeAttribute('aria-busy');
        }
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    function createCommentElement(comment, isReply = false) {
        const commentDiv = document.createElement('div');
        commentDiv.className = isReply ? 'comment reply' : 'comment';
        commentDiv.dataset.commentId = comment.id;

        const date = new Date(comment.createdAt).toLocaleDateString('de-DE', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
        });

        const userId = getUserId();
        const isLiked = comment.userLikes && comment.userLikes[userId];

        commentDiv.innerHTML = `
            <div class="comment-header">
                <div class="comment-author">${escapeHtml(comment.username)}</div>
                <div class="comment-date">${date}</div>
            </div>
            <div class="comment-content">${escapeHtml(comment.content)}</div>
            <div class="comment-actions">
                <button class="comment-like-btn ${isLiked ? 'liked' : ''}" onclick="window.likeComment('${comment.id}')">
                    <i class="fas fa-thumbs-up"></i>
                    <span class="like-count">${comment.likes || 0}</span>
                </button>
                ${!isReply ? `<button class="comment-reply-btn" onclick="window.showReplyForm('${comment.id}')"><i class="fas fa-reply"></i> Antworten</button>` : ''}
                ${comment.userId === userId ? `<button class="comment-delete-btn" onclick="window.deleteComment('${comment.id}')" style="background:none;border:none;color:var(--accent);cursor:pointer;font-size:0.7rem;"><i class="fas fa-trash"></i> Löschen</button>` : ''}
            </div>
            <div class="reply-form-container" id="replyForm-${comment.id}"></div>
            <div class="comment-replies" id="replies-${comment.id}">
                ${comment.replies && comment.replies.length ? comment.replies.map((reply) => createCommentElement(reply, true).outerHTML).join('') : ''}
            </div>
        `;

        return commentDiv;
    }

    function updatePagination(data) {
        const prevBtn = document.getElementById('prevPage');
        const nextBtn = document.getElementById('nextPage');
        const pageInfo = document.getElementById('pageInfo');

        if (prevBtn) {
            prevBtn.disabled = communityState.currentPage === 1;
        }
        if (nextBtn) {
            nextBtn.disabled = communityState.currentPage >= (data.totalPages || 1);
        }
        if (pageInfo) {
            pageInfo.textContent = `Seite ${data.page || 1} von ${data.totalPages || 1}`;
        }
    }

    async function loadComments() {
        const list = document.getElementById('commentsList');
        const sort = document.getElementById('sortComments');
        if (!list || !sort) {
            return;
        }

        list.innerHTML = '<div class="loading-comments">Lade Kommentare...</div>';

        try {
            const data = await requestJson(
                `https://api.joeyslime.com/api/comments?page=${communityState.currentPage}&limit=${communityState.commentsPerPage}&sort=${sort.value}`
            );

            if (!data.comments || !data.comments.length) {
                list.innerHTML = '<div class="no-comments">Noch keine Kommentare. Sei der Erste, der kommentiert.</div>';
            } else {
                list.innerHTML = '';
                data.comments.forEach((comment) => {
                    list.appendChild(createCommentElement(comment));
                });
            }

            updatePagination(data);
        } catch (error) {
            console.error('Error loading comments:', error);
            list.innerHTML = '<div class="no-comments">Fehler beim Laden der Kommentare.</div>';
        }
    }

    async function submitReply(form, parentId) {
        const username = form.querySelector('input')?.value.trim();
        const content = form.querySelector('textarea')?.value.trim();

        if (!username || !content) {
            window.alert('Bitte fülle alle Felder aus.');
            return;
        }

        try {
            const data = await requestJson('https://api.joeyslime.com/api/comments', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    username,
                    content,
                    userId: getUserId(),
                    parentId,
                }),
            });

            if (!data.success) {
                throw new Error(data.error || 'Antwort konnte nicht gespeichert werden');
            }

            form.remove();
            loadComments();
        } catch (error) {
            console.error('Error submitting reply:', error);
            window.alert(error.message || 'Fehler beim Senden der Antwort');
        }
    }

    function showReplyForm(parentId) {
        const container = document.getElementById(`replyForm-${parentId}`);
        if (!container) {
            return;
        }

        const existing = container.querySelector('.reply-form');
        if (existing) {
            existing.remove();
            return;
        }

        const form = document.createElement('form');
        form.className = 'reply-form';
        form.innerHTML = `
            <div class="form-group">
                <input type="text" class="form-control" placeholder="Dein Name" maxlength="30" required>
            </div>
            <div class="form-group">
                <textarea class="form-control" placeholder="Schreibe eine Antwort..." maxlength="500" required></textarea>
                <div class="char-counter"><span>0</span>/500 Zeichen</div>
            </div>
            <div class="form-buttons">
                <button type="submit" class="btn btn-primary btn-small">Antwort senden</button>
                <button type="button" class="btn btn-secondary btn-small">Abbrechen</button>
            </div>
        `;

        form.querySelector('textarea')?.addEventListener('input', function () {
            const counter = form.querySelector('.char-counter span');
            if (counter) {
                counter.textContent = String(this.value.length);
            }
            form.querySelector('.char-counter')?.classList.toggle('warning', this.value.length > 450);
        });

        form.addEventListener('submit', (event) => {
            event.preventDefault();
            submitReply(form, parentId);
        });

        form.querySelector('button[type="button"]')?.addEventListener('click', () => form.remove());
        container.appendChild(form);
    }

    async function likeComment(commentId) {
        try {
            const data = await requestJson(`https://api.joeyslime.com/api/comments/${commentId}/like`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ userId: getUserId() }),
            });

            if (!data.success) {
                throw new Error(data.error || 'Kommentar-Like fehlgeschlagen');
            }

            loadComments();
        } catch (error) {
            console.error('Error liking comment:', error);
            window.alert(error.message || 'Fehler beim Liken des Kommentars');
        }
    }

    async function deleteComment(commentId) {
        if (!window.confirm('Möchtest du diesen Kommentar wirklich löschen?')) {
            return;
        }

        try {
            const data = await requestJson(`https://api.joeyslime.com/api/comments/${commentId}`, {
                method: 'DELETE',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ userId: getUserId() }),
            });

            if (!data.success) {
                throw new Error(data.error || 'Kommentar konnte nicht gelöscht werden');
            }

            loadComments();
        } catch (error) {
            console.error('Error deleting comment:', error);
            window.alert(error.message || 'Fehler beim Löschen des Kommentars');
        }
    }

    function changePage(direction) {
        communityState.currentPage += direction;
        if (communityState.currentPage < 1) {
            communityState.currentPage = 1;
        }
        loadComments();
    }

    function initCommentForm() {
        const form = document.getElementById('commentForm');
        const textarea = document.getElementById('commentContent');
        const sort = document.getElementById('sortComments');
        const prev = document.getElementById('prevPage');
        const next = document.getElementById('nextPage');
        const likeBtn = document.getElementById('likeBtn');

        if (likeBtn) {
            likeBtn.addEventListener('click', toggleLike);
        }

        if (sort) {
            sort.addEventListener('change', () => {
                communityState.currentPage = 1;
                loadComments();
            });
        }

        if (prev) {
            prev.addEventListener('click', () => changePage(-1));
        }

        if (next) {
            next.addEventListener('click', () => changePage(1));
        }

        if (textarea) {
            textarea.addEventListener('input', function () {
                const counter = document.getElementById('charCount');
                if (counter) {
                    counter.textContent = String(this.value.length);
                    counter.parentElement?.classList.toggle('warning', this.value.length > 450);
                }
            });
        }

        if (!form) {
            return;
        }

        form.addEventListener('submit', async (event) => {
            event.preventDefault();

            const username = document.getElementById('username')?.value.trim();
            const content = textarea?.value.trim();

            if (!username || !content) {
                window.alert('Bitte fülle alle Felder aus.');
                return;
            }

            try {
                const data = await requestJson('https://api.joeyslime.com/api/comments', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ username, content, userId: getUserId() }),
                });

                if (!data.success) {
                    throw new Error(data.error || 'Kommentar konnte nicht gespeichert werden');
                }

                form.reset();
                const charCount = document.getElementById('charCount');
                if (charCount) {
                    charCount.textContent = '0';
                    charCount.parentElement?.classList.remove('warning');
                }
                communityState.currentPage = 1;
                loadComments();
            } catch (error) {
                console.error('Error submitting comment:', error);
                window.alert(error.message || 'Fehler beim Senden des Kommentars');
            }
        });
    }

    function initCommunity() {
        if (!document.getElementById('community')) {
            return;
        }

        initCommentForm();
        loadLikes();
        loadComments();

        window.toggleLike = toggleLike;
        window.showReplyForm = showReplyForm;
        window.likeComment = likeComment;
        window.deleteComment = deleteComment;
        window.changePage = changePage;
    }

    function initTargetCursor() {
        const storageKey = 'slimeventure_target_cursor_enabled';
        const supportsFinePointer = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
        const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        const controller = {
            supported: supportsFinePointer && !prefersReducedMotion,
            enabled: false,
            onChange: null,
            enable: () => {},
            disable: () => {},
            toggle: () => {},
        };

        if (!controller.supported) {
            return controller;
        }

        const nativeFieldSelector =
            'input:not([type="button"]):not([type="submit"]):not([type="reset"]):not([type="checkbox"]):not([type="radio"]), textarea, select, [contenteditable="true"]';
        const targetSelector = [
            'a[href]',
            'button',
            'summary',
            '[role="button"]',
            '[role="link"]',
            '.logo',
            '.quick-finder',
            '.site-command__close',
            '.site-command__item',
            '.social-loop__item',
            '.hamburger-menu',
            '.cursor-toggle',
            '.back-to-top',
        ].join(', ');
        const defaultOffsets = [
            { x: -18, y: -18 },
            { x: 8, y: -18 },
            { x: 8, y: 8 },
            { x: -18, y: 8 },
        ];

        let wrapper = null;
        let dot = null;
        let corners = [];
        let listenerCleanups = [];
        let currentOffsets = defaultOffsets.map((point) => ({ ...point }));
        let targetOffsets = defaultOffsets.map((point) => ({ ...point }));

        let pointerX = window.innerWidth / 2;
        let pointerY = window.innerHeight / 2;
        let currentX = pointerX;
        let currentY = pointerY;
        let pressed = false;
        let visible = false;
        let hiddenForNativeField = false;
        let activeTarget = null;
        let rotation = 0;
        let rafId = 0;

        const notify = () => {
            if (typeof controller.onChange === 'function') {
                controller.onChange({
                    supported: controller.supported,
                    enabled: controller.enabled,
                });
            }
        };

        const ensureCursorDom = () => {
            if (wrapper) {
                return;
            }

            wrapper = document.createElement('div');
            wrapper.className = 'target-cursor-wrapper';
            wrapper.innerHTML = `
                <div class="target-cursor-dot"></div>
                <div class="target-cursor-corner corner-tl"></div>
                <div class="target-cursor-corner corner-tr"></div>
                <div class="target-cursor-corner corner-br"></div>
                <div class="target-cursor-corner corner-bl"></div>
            `;
            document.body.appendChild(wrapper);
            dot = wrapper.querySelector('.target-cursor-dot');
            corners = Array.from(wrapper.querySelectorAll('.target-cursor-corner'));
            currentOffsets = defaultOffsets.map((point) => ({ ...point }));
            targetOffsets = defaultOffsets.map((point) => ({ ...point }));
        };

        const setVisibility = () => {
            if (!wrapper) {
                return;
            }
            const shouldShow = visible && !hiddenForNativeField;
            wrapper.classList.toggle('is-visible', shouldShow);
        };

        const resetTargetOffsets = () => {
            defaultOffsets.forEach((point, index) => {
                targetOffsets[index].x = point.x;
                targetOffsets[index].y = point.y;
            });
        };

        const releaseTarget = () => {
            activeTarget = null;
            if (wrapper) {
                wrapper.classList.remove('is-targeting');
            }
            resetTargetOffsets();
        };

        const updateTargetOffsets = () => {
            if (!activeTarget || !document.body.contains(activeTarget)) {
                releaseTarget();
                return;
            }

            const rect = activeTarget.getBoundingClientRect();
            if (!rect.width || !rect.height) {
                releaseTarget();
                return;
            }

            const padding = 6;
            const cornerSize = 14;
            targetOffsets[0].x = rect.left - currentX - padding;
            targetOffsets[0].y = rect.top - currentY - padding;
            targetOffsets[1].x = rect.right - currentX + padding - cornerSize;
            targetOffsets[1].y = rect.top - currentY - padding;
            targetOffsets[2].x = rect.right - currentX + padding - cornerSize;
            targetOffsets[2].y = rect.bottom - currentY + padding - cornerSize;
            targetOffsets[3].x = rect.left - currentX - padding;
            targetOffsets[3].y = rect.bottom - currentY + padding - cornerSize;
        };

        const tick = () => {
            if (!controller.enabled || !wrapper || !dot || corners.length !== 4) {
                rafId = 0;
                return;
            }

            currentX += (pointerX - currentX) * 0.2;
            currentY += (pointerY - currentY) * 0.2;

            if (activeTarget) {
                updateTargetOffsets();
            } else {
                rotation = (rotation + 1.5) % 360;
            }

            const displayRotation = activeTarget ? 0 : rotation;
            wrapper.style.transform = `translate3d(${currentX}px, ${currentY}px, 0) rotate(${displayRotation}deg)`;

            currentOffsets.forEach((offset, index) => {
                const strength = activeTarget ? 0.24 : 0.18;
                offset.x += (targetOffsets[index].x - offset.x) * strength;
                offset.y += (targetOffsets[index].y - offset.y) * strength;
                corners[index].style.transform = `translate3d(${offset.x}px, ${offset.y}px, 0)`;
            });

            const dotScale = pressed ? 0.82 : activeTarget ? 1.12 : 1;
            dot.style.transform = `translate3d(-3px, -3px, 0) scale(${dotScale})`;

            rafId = window.requestAnimationFrame(tick);
        };

        const addListener = (target, eventName, handler, options) => {
            target.addEventListener(eventName, handler, options);
            listenerCleanups.push(() => target.removeEventListener(eventName, handler, options));
        };

        const attachListeners = () => {
            const moveHandler = (event) => {
                if (!document.body.classList.contains('target-cursor-enabled')) {
                    document.body.classList.add('target-cursor-enabled');
                }
                pointerX = event.clientX;
                pointerY = event.clientY;
                visible = true;
                hiddenForNativeField = Boolean(event.target.closest(nativeFieldSelector));
                setVisibility();

                if (!hiddenForNativeField && !rafId) {
                    rafId = window.requestAnimationFrame(tick);
                }
            };

            const overHandler = (event) => {
                const nativeField = event.target.closest(nativeFieldSelector);
                hiddenForNativeField = Boolean(nativeField);
                setVisibility();

                if (nativeField) {
                    releaseTarget();
                    return;
                }

                const target = event.target.closest(targetSelector);
                if (!target || target.disabled || target.getAttribute('aria-disabled') === 'true') {
                    releaseTarget();
                    return;
                }

                activeTarget = target;
                if (wrapper) {
                    wrapper.classList.add('is-targeting');
                }
            };

            const leaveWindowHandler = (event) => {
                if (event.relatedTarget) {
                    return;
                }
                visible = false;
                hiddenForNativeField = false;
                releaseTarget();
                setVisibility();
            };

            const downHandler = () => {
                pressed = true;
            };

            const upHandler = () => {
                pressed = false;
            };

            const blurHandler = () => {
                visible = false;
                hiddenForNativeField = false;
                releaseTarget();
                setVisibility();
            };

            addListener(window, 'mousemove', moveHandler, { passive: true });
            addListener(window, 'mouseover', overHandler, { passive: true });
            addListener(window, 'mouseout', leaveWindowHandler);
            addListener(window, 'mousedown', downHandler, { passive: true });
            addListener(window, 'mouseup', upHandler, { passive: true });
            addListener(window, 'blur', blurHandler);
        };

        const detachListeners = () => {
            listenerCleanups.forEach((cleanup) => cleanup());
            listenerCleanups = [];
        };

        const stopAnimation = () => {
            if (rafId) {
                window.cancelAnimationFrame(rafId);
                rafId = 0;
            }
        };

        const destroyCursorDom = () => {
            if (wrapper) {
                wrapper.remove();
            }
            wrapper = null;
            dot = null;
            corners = [];
        };

        controller.enable = (persist = true) => {
            if (controller.enabled) {
                if (persist) {
                    safeStorageSet(storageKey, '1');
                }
                notify();
                return;
            }

            controller.enabled = true;
            ensureCursorDom();
            attachListeners();
            releaseTarget();
            visible = false;
            hiddenForNativeField = false;
            pressed = false;
            rotation = 0;
            setVisibility();

            if (persist) {
                safeStorageSet(storageKey, '1');
            }
            notify();
        };

        controller.disable = (persist = true) => {
            if (!controller.enabled && !wrapper) {
                if (persist) {
                    safeStorageSet(storageKey, '0');
                }
                notify();
                return;
            }

            controller.enabled = false;
            detachListeners();
            stopAnimation();
            visible = false;
            hiddenForNativeField = false;
            pressed = false;
            releaseTarget();
            setVisibility();
            document.body.classList.remove('target-cursor-enabled');
            destroyCursorDom();

            if (persist) {
                safeStorageSet(storageKey, '0');
            }
            notify();
        };

        controller.toggle = () => {
            if (controller.enabled) {
                controller.disable();
                return;
            }
            controller.enable();
        };

        const savedPreference = safeStorageGet(storageKey);
        if (savedPreference !== '0') {
            controller.enable(false);
        } else {
            notify();
        }

        return controller;
    }

    function initCursorToggle(cursorController) {
        const button = document.getElementById('cursorToggle');
        if (!button) {
            return;
        }

        if (!cursorController || !cursorController.supported) {
            button.hidden = true;
            return;
        }

        const icon = button.querySelector('i');
        const render = ({ enabled }) => {
            button.classList.toggle('is-off', !enabled);
            button.setAttribute('aria-pressed', enabled ? 'true' : 'false');
            button.setAttribute('aria-label', enabled ? 'Spezialcursor deaktivieren' : 'Spezialcursor aktivieren');
            button.title = enabled ? 'Spezialcursor deaktivieren' : 'Spezialcursor aktivieren';
            if (icon) {
                icon.className = enabled ? 'fas fa-crosshairs' : 'fas fa-arrow-pointer';
            }
        };

        cursorController.onChange = render;
        render({ enabled: cursorController.enabled });
        button.addEventListener('click', () => {
            cursorController.toggle();
        });
    }

    function initServiceWorker() {
        if (!('serviceWorker' in navigator)) {
            return;
        }

        if (!/^https?:$/.test(window.location.protocol)) {
            return;
        }

        window.addEventListener('load', () => {
            navigator.serviceWorker.register(siteUrl('sw.js')).catch((error) => {
                console.log('ServiceWorker registration failed:', error);
            });
        });
    }

    ready(() => {
        initLoadingBar();
        normalizeFileSchemeLinks();
        initNav();
        initQuickFinder();
        initSocialLoopFallback();
        initScrollReveal();
        initScrollFloat();
        initBackToTop();
        initDevlogFilters();
        initWikiSearch();
        initCommunity();
        const cursorController = initTargetCursor();
        initCursorToggle(cursorController);
        initServiceWorker();
    });
})();
