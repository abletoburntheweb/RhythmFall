/* global window, document */
(function () {
	"use strict";

	const CARD = window.__CARD__ || {};
	const root = document.getElementById("card");
	if (!root || !CARD.card_id) {
		return;
	}

	const accent = CARD.accent || "#9f85eb";
	const accent2 = CARD.accent2 || accent;
	document.documentElement.style.setProperty("--accent", accent);
	document.documentElement.style.setProperty("--accent2", accent2);
	document.documentElement.style.setProperty("--accent-soft", accent + "66");
	document.documentElement.style.setProperty("--accent-glow", accent + "55");
	if (CARD.locale) {
		document.documentElement.lang = String(CARD.locale).split(/[-_]/)[0] || "en";
	}
	root.className = "card card--" + esc(CARD.card_id);

	function esc(s) {
		return String(s ?? "")
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}

	function fmtInt(n) {
		const v = Number(n) || 0;
		if (v >= 1_000_000) return (v / 1_000_000).toFixed(1).replace(/\.0$/, "") + "M";
		if (v >= 10_000) return Math.round(v / 1000) + "k";
		return String(v);
	}

	function header(index, brand) {
		return `<div class="card-top">
			<div class="card-glow-orb"></div>
			<div class="card-glow-orb card-glow-orb--b"></div>
			<div class="card-mesh"></div>
			<div class="card-header"><span class="index">${esc(String(index).padStart(2, "0"))}</span><span class="brand">${esc(brand)}</span></div>
		</div>`;
	}

	function heroBlock(title, subtitle) {
		const sub = subtitle && String(subtitle).trim() ? `<div class="hero-subtitle">${esc(subtitle)}</div>` : "";
		return `<div class="hero-banner">
			<div class="card-hero-title">${esc(title)}</div>
			${sub}
			<div class="hero-line"></div>
		</div>`;
	}

	function footer(site, date) {
		return `<div class="card-footer"><span>${esc(site)}</span><span>${esc(date)}</span></div>`;
	}

	function sectionTitle(text) {
		return `<div class="section-title"><span class="section-bar"></span>${esc(text)}</div>`;
	}

	function progressBar(ratio, label) {
		const pct = Math.max(0, Math.min(100, Number(ratio) * 100));
		return `<div class="progress-wrap"><div class="progress-bar"><div class="progress-fill" style="width:${pct}%"></div></div>${label ? `<div class="progress-label">${esc(label)}</div>` : ""}</div>`;
	}

	function statChip(value, caption, accentChip) {
		return `<div class="glass stat-chip${accentChip ? " accent" : ""}"><div class="value">${esc(value)}</div><div class="caption">${esc(caption)}</div></div>`;
	}

	function modIconChip(icon, size) {
		if (!icon || !icon.b64) {
			return "";
		}
		const px = Number(size) || 24;
		const tint = icon.tint || accent;
		return `<span class="mod-icon-chip" style="--mod-tint:${esc(tint)}"><img src="data:image/png;base64,${icon.b64}" width="${px}" height="${px}" alt=""/></span>`;
	}

	function modIconStrip(icons, size) {
		if (!icons || !icons.length) {
			return "";
		}
		return `<div class="mod-icon-strip">${icons.map((ic) => modIconChip(ic, size)).join("")}</div>`;
	}

	function genreIconFrame(icon, size) {
		if (!icon || !icon.b64) {
			return `<div class="genre-icon genre-icon--fallback">♫</div>`;
		}
		const px = Number(size) || 56;
		const tint = icon.tint || accent;
		return `<div class="genre-icon" style="--genre-tint:${esc(tint)}"><img src="data:image/png;base64,${icon.b64}" width="${px}" height="${px}" alt=""/></div>`;
	}

	function genreIconChip(icon, size) {
		if (!icon || !icon.b64) {
			return "";
		}
		const px = Number(size) || 22;
		const tint = icon.tint || accent;
		return `<span class="genre-icon-chip" style="--genre-tint:${esc(tint)}"><img src="data:image/png;base64,${icon.b64}" width="${px}" height="${px}" alt=""/></span>`;
	}

	function factPanel(factText, L) {
		if (!factText || !String(factText).trim()) {
			return "";
		}
		return `${sectionTitle(L.sec_fact || "—")}
			<div class="glass glass-accent fact-panel fact-panel--compact">
				<div class="fact-icon">✦</div>
				<div class="fact-text-block"><div class="fact-primary">${esc(factText)}</div></div>
			</div>`;
	}

	function collectionRing(pct, unlocked, total) {
		const r = 52;
		const c = 2 * Math.PI * r;
		const ratio = Math.min(100, Math.max(0, Number(pct) || 0));
		const dash = c * ratio / 100;
		const ac = getComputedStyle(document.documentElement).getPropertyValue("--accent").trim() || "#34d399";
		return `<div class="collection-ring-wrap">
			<svg viewBox="0 0 120 120" width="120" height="120">
				<circle cx="60" cy="60" r="${r}" fill="none" stroke="rgba(255,255,255,0.12)" stroke-width="10"/>
				<circle cx="60" cy="60" r="${r}" fill="none" stroke="${ac}" stroke-width="10"
					stroke-dasharray="${dash} ${c}" stroke-linecap="round" transform="rotate(-90 60 60)"/>
			</svg>
			<div class="ring-center"><div class="ring-num">${esc(unlocked)}</div><div class="ring-of">/${esc(total)}</div></div>
		</div>`;
	}

	function gradeBadges(c, keys) {
		return keys.map(([g, field, cls]) =>
			`<div class="grade-badge glass ${cls}"><div class="letter">${g}</div><div class="count">${fmtInt(c[field] || 0)}</div></div>`
		).join("");
	}

	function renderOverview(c) {
		const L = c.labels || {};
		const cover = c.cover_b64
			? `<img class="cover" src="data:image/png;base64,${c.cover_b64}" alt="">`
			: `<div class="cover cover-placeholder">♪</div>`;
		const gradeKeys = [["SS", "ss", "grade-ss"], ["S", "s", "grade-s"], ["A", "a", "grade-a"], ["B", "b", "grade-b"]];
		return `
			${header(c.card_index, c.brand)}
			${heroBlock(c.hero_title, c.hero_subtitle)}
			<div class="card-body">
				<div class="glass glass-accent hero-panel hero-panel--rr">
					<div class="hero-value">${fmtInt(c.rr_earned)}</div>
					<div class="hero-caption">${esc(L.rr || "—")}</div>
				</div>
				${c.member_since ? `<div class="member-since glass">${esc(c.member_since)}</div>` : ""}
				<div class="glass glass-accent level-panel">
					<div class="level-value">${esc(c.level_label)}</div>
					${progressBar(c.xp_ratio, c.xp_text)}
				</div>
				<div class="stats-grid stats-grid-4">
					${statChip((Number(c.accuracy).toFixed(1) + "%"), L.accuracy || "—", true)}
					${statChip(c.play_time, L.play_time || "—")}
					${statChip(fmtInt(c.levels_completed || 0), L.tracks || "—")}
					${statChip(fmtInt(c.medals_total || 0), L.medals || "—")}
					${statChip(fmtInt(c.max_combo || 0), L.combo || "—")}
					${statChip(fmtInt(c.total_score || 0), L.score || "—")}
					${statChip(fmtInt(c.daily_quests || 0), L.daily || "—")}
					${statChip(c.avg_difficulty_text || "—", L.avg_diff || "—")}
				</div>
				${sectionTitle(L.sec_grades || "—")}
				<div class="grades-row grades-row-4">${gradeBadges(c, gradeKeys)}</div>
				${sectionTitle(L.sec_fav_track || "—")}
				<div class="glass fav-row">
					${cover}
					<div class="fav-info">
						<div class="fav-title">${esc(c.title)}</div>
						<div class="fav-artist">${esc(c.artist)}</div>
						<div class="fav-meta">${esc(c.genre)} · ${esc(c.play_count)} ${esc(L.plays || "—")}${c.best_grade ? " · " + esc(L.best_grade || "—") + " " + esc(c.best_grade) : ""}</div>
					</div>
				</div>
				${sectionTitle(L.sec_fav_genre || "—")}
				<div class="glass glass-accent genre-fav">
					${genreIconFrame(c.favorite_group_icon, 56)}
					<div>
						<div class="genre-fav-name">${esc(c.favorite_group || L.empty_genre || "—")}</div>
						<div class="genre-fav-pct">${esc(c.genre_percent_text || "")}</div>
					</div>
				</div>
				${factPanel(c.card_fact, L)}
			</div>
			${footer(c.footer_site, c.footer_date)}
		`;
	}

	function renderStatistics(c) {
		const L = c.labels || {};
		const combat = [
			[c.notes_miss, L.miss || "—"],
			[c.max_combo, L.combo || "—"],
			[c.total_score, L.score || "—", true],
		];
		const progress = [
			[c.unique_tracks, L.tracks || "—"],
			[c.medals_total, L.medals || "—"],
			[c.rr_earned, L.rr || "—", true],
			[c.daily_quests, L.daily || "—"],
			[c.avg_difficulty_text || "—", L.avg_diff || "—"],
		];
		const chipHtml = (rows) => rows.map((row) => {
			let val = row[0];
			val = typeof val === "number" ? fmtInt(val) : String(val);
			return statChip(val, row[1], row[2]);
		}).join("");

		const gradeKeys = [["SS", "ss", "grade-ss"], ["S", "s", "grade-s"], ["A", "a", "grade-a"], ["B", "b", "grade-b"]];
		const chart = buildChart(c.accuracy_points || []);

		return `
			${header(c.card_index, c.brand)}
			${heroBlock(c.hero_title, c.hero_subtitle)}
			<div class="card-body">
				<div class="glass glass-accent hero-panel">
					<div class="hero-value">${Number(c.hit_rate || 0).toFixed(1)}%</div>
					<div class="hero-caption">${esc(L.hit_rate || "—")}</div>
					${c.hero_sub_text ? `<div class="hero-subcaption">${esc(c.hero_sub_text)}</div>` : ""}
				</div>
				${sectionTitle(L.sec_combat || "—")}
				<div class="stats-grid stats-grid-3">${chipHtml(combat)}</div>
				${sectionTitle(L.sec_progress || "—")}
				<div class="stats-grid stats-grid-3">${chipHtml(progress)}</div>
				${sectionTitle(L.sec_grades || "—")}
				<div class="grades-row grades-row-4">${gradeBadges(c, gradeKeys)}</div>
				${sectionTitle(L.sec_chart || "—")}
				<div class="glass chart-panel chart-panel--stats">
					${chart}
					${c.chart_caption ? `<div class="chart-caption">${esc(c.chart_caption)}</div>` : ""}
				</div>
				${factPanel(c.card_fact, L)}
			</div>
			${footer(c.footer_site, c.footer_date)}
		`;
	}

	function buildChart(points) {
		if (!points.length) {
			return `<svg viewBox="0 0 900 200" preserveAspectRatio="none"><text x="450" y="100" text-anchor="middle" fill="rgba(180,190,210,0.45)" font-size="22">—</text></svg>`;
		}
		const w = 900, h = 200, pad = 12;
		const nums = points.map((v) => Math.max(0, Math.min(100, Number(v) || 0)));
		const avg = nums.reduce((a, b) => a + b, 0) / nums.length;
		const coords = nums.map((v, i) => {
			const x = pad + (nums.length <= 1 ? 0 : (w - pad * 2) * i / (nums.length - 1));
			const y = h - pad - (v / 100) * (h - pad * 2);
			return [x, y];
		});
		const line = coords.map((p) => p.join(",")).join(" ");
		const fill = `${pad},${h - pad} ${line} ${w - pad},${h - pad}`;
		const ac = getComputedStyle(document.documentElement).getPropertyValue("--accent").trim() || "#38bdf8";
		const ac2 = getComputedStyle(document.documentElement).getPropertyValue("--accent2").trim() || "#22d3ee";
		const grid = [25, 50, 75, 100].map((pct) => {
			const y = h - pad - (pct / 100) * (h - pad * 2);
			return `<line x1="${pad}" y1="${y}" x2="${w - pad}" y2="${y}" stroke="rgba(255,255,255,0.07)" stroke-width="1" stroke-dasharray="5 7"/>`;
		}).join("");
		const avgY = h - pad - (avg / 100) * (h - pad * 2);
		const avgLine = `<line x1="${pad}" y1="${avgY}" x2="${w - pad}" y2="${avgY}" stroke="${ac2}" stroke-opacity="0.55" stroke-width="2.5" stroke-dasharray="6 5"/>`;
		return `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="none">
			<defs>
				<linearGradient id="chartGrad" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="${ac}" stop-opacity="0.42"/><stop offset="100%" stop-color="${ac2}" stop-opacity="0.04"/></linearGradient>
				<linearGradient id="chartLine" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="${ac2}"/><stop offset="100%" stop-color="${ac}"/></linearGradient>
			</defs>
			${grid}
			${avgLine}
			<polygon points="${fill}" fill="url(#chartGrad)"/>
			<polyline points="${line}" fill="none" stroke="url(#chartLine)" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
		</svg>`;
	}

	function renderMusic(c) {
		const L = c.labels || {};
		const genres = (c.top_genres || []).map((g) => {
			const lv = g.mastery_level > 0
				? (L.level_short || "Ур.%d").replace("%d", String(g.mastery_level))
				: "—";
			const color = esc(g.color || "var(--accent)");
			return `<div class="genre-mastery-row glass">
				<div class="genre-mastery-head">
					<div class="genre-mastery-title">
						${genreIconChip(g.icon, 22)}
						<div class="genre-name">${esc(g.name)}</div>
					</div>
					<div class="genre-mastery-badge">${esc(lv)}</div>
				</div>
				<div class="genre-mastery-bars">
					<div class="genre-bar"><div class="genre-bar-fill" style="width:${Math.min(100, g.percent)}%;background:linear-gradient(90deg,${color},${color}88)"></div></div>
					<div class="genre-pct" style="color:${color}">${Math.round(g.percent)}%</div>
				</div>
			</div>`;
		}).join("");

		return `
			${header(c.card_index, c.brand)}
			${heroBlock(c.hero_title, c.hero_subtitle)}
			<div class="card-body">
				${c.hero_genre_name ? `<div class="glass glass-accent hero-panel hero-panel--genre">
					<div class="hero-genre-head">
						${genreIconFrame(c.hero_genre_icon, 48)}
						<div>
							<div class="hero-value hero-value--genre">${esc(c.hero_genre_name)}</div>
							<div class="hero-caption">${esc(c.hero_genre_percent_text || "")}</div>
						</div>
					</div>
				</div>` : ""}
				${sectionTitle(L.sec_genres || "—")}
				<div class="list-gap">${genres || `<div class="genre-name">${esc(L.empty_genre || "—")}</div>`}</div>
				${sectionTitle(L.sec_collection || "—")}
				<div class="glass glass-accent collection-panel">
					${collectionRing(c.collection_percent || 0, c.groups_unlocked, c.groups_total)}
					<div class="collection-details">
						<div class="collection-line">${esc(c.collection_groups_text || "")}</div>
						<div class="collection-line">${esc(c.collection_genres_text || "")}</div>
						${c.collection_full_text ? `<div class="collection-line">${esc(c.collection_full_text)}</div>` : ""}
						${c.collection_best_text ? `<div class="collection-line collection-line--accent">${esc(c.collection_best_text)}</div>` : ""}
					</div>
				</div>
				<div class="mastery-hint glass">${esc(L.sec_mastery_hint || "")}</div>
				${factPanel(c.card_fact, L)}
			</div>
			${footer(c.footer_site, c.footer_date)}
		`;
	}

	function renderRecords(c) {
		const L = c.labels || {};
		const milestones = (c.milestones || []).map((m) => `
			<div class="glass milestone-chip ${m.unlocked ? "unlocked" : "locked"}">
				<div class="mark">${m.unlocked ? "✦" : "·"}</div>
				<div class="title">${esc(m.title)}</div>
			</div>
		`).join("");

		const rrTop = (c.rr_top || []).map((row) => `
			<div class="glass rr-top-row">
				<div class="rr-rank">${String(row.rank || 0).padStart(2, "0")}</div>
				<div class="rr-track">${esc(row.track || "—")}</div>
				<div class="rr-value">${fmtInt(row.rr)}</div>
			</div>
		`).join("");

		const records = (c.records || []).map((r) => `
			<div class="glass record-row">
				<div class="record-main">
					<div class="caption">${esc(r.caption)}</div>
					${r.track ? `<div class="record-track">${esc(r.track)}</div>` : ""}
				</div>
				<div class="value">${esc(r.value)}</div>
			</div>
		`).join("");

		const mods = (c.mod_rows || []).map((r) => `
			<div class="glass record-row mod-row">
				<div class="record-main">
					<div class="caption">${esc(r.caption)}</div>
					${r.icons && r.icons.length ? modIconStrip(r.icons, 22) : ""}
				</div>
				<div class="value">${esc(r.value)}</div>
			</div>
		`).join("");

		return `
			${header(c.card_index, c.brand)}
			${heroBlock(c.hero_title, c.hero_subtitle)}
			<div class="card-body">
				<div class="glass glass-accent hero-panel hero-panel--rr">
					<div class="hero-value">${fmtInt(c.best_rr_peak || 0)}</div>
					<div class="hero-caption">${esc(L.rr_peak || "—")}</div>
					${c.best_rr_track ? `<div class="hero-subcaption">${esc(c.best_rr_track)}</div>` : ""}
				</div>
				${rrTop ? sectionTitle(L.sec_rr_top || "—") + `<div class="list-gap">${rrTop}</div>` : ""}
				${sectionTitle(L.sec_milestones || "—")}
				<div class="milestones-row milestones-row-6">${milestones}</div>
				${sectionTitle(L.sec_records || "—")}
				<div class="list-gap">${records}</div>
				${mods ? sectionTitle(L.sec_mods || "—") + `<div class="list-gap">${mods}</div>` : ""}
				${factPanel(c.card_fact, L)}
			</div>
			${footer(c.footer_site, c.footer_date)}
		`;
	}

	function renderPlayModes(c) {
		const L = c.labels || {};
		const heroCaption = L[c.hero_caption_key] || L.hero_mods || "—";
		const heroIcon = c.top_mod_icon && c.top_mod_icon.b64 && c.hero_kind === "mods"
			? modIconChip(c.top_mod_icon, 36)
			: "";

		const marathonRows = (c.marathon_rows || []).map((row) => `
			<div class="glass play-mode-row">
				<div class="play-mode-main">
					<div class="play-mode-title">${esc(row.title || "—")}</div>
					${row.badge_label ? `<div class="play-mode-badge">${esc(row.badge_label)}</div>` : ""}
				</div>
				<div class="play-mode-value">${esc(row.ratio_text || "—")}</div>
			</div>
		`).join("");

		const modGrid = (c.mod_clear_rows || []).map((row) => `
			<div class="glass mod-clear-tile">
				${row.icon && row.icon.b64 ? modIconChip(row.icon, 28) : ""}
				<div class="mod-clear-count">${fmtInt(row.count || 0)}</div>
			</div>
		`).join("");

		const endlessHasData = Boolean(c.endless_has_data);
		const endlessSection = `${sectionTitle(L.endless || "—")}
			${endlessHasData
				? `<div class="stat-grid stat-grid-2">
					${statChip(fmtInt(c.endless_best_streak || 0), L.endless_streak || "—", true)}
					${statChip(
						c.endless_best_accuracy > 0 ? (Number(c.endless_best_accuracy).toFixed(1) + "%") : "—",
						L.endless_accuracy || "—",
						false
					)}
				</div>`
				: `<div class="glass play-modes-empty">${esc(L.endless_empty || "—")}</div>`
			}`;

		const marathonHasData = Boolean(c.marathon_has_data);
		const marathonSection = `${sectionTitle(L.marathon || "—")}
			${marathonHasData
				? `<div class="glass glass-accent play-modes-summary">
					<div class="play-modes-summary-line">${esc(c.marathon_routes_text || "")}</div>
					${c.marathon_badge ? `<div class="play-modes-summary-sub">${esc(c.marathon_badge)}</div>` : ""}
				</div>
				${marathonRows ? `<div class="list-gap">${marathonRows}</div>` : ""}`
				: `<div class="glass play-modes-empty">${esc(L.marathon_empty || "—")}</div>`
			}`;

		const modSection = `${sectionTitle(L.mod_clears || "—")}
			<div class="play-modes-summary-line play-modes-mastered">${esc(c.mods_mastered_text || "")}</div>
			${c.mod_clear_rows && c.mod_clear_rows.length
				? `<div class="mod-clear-grid">${modGrid}</div>`
				: `<div class="glass play-modes-empty">${esc(L.mods_empty || "—")}</div>`
			}`;

		return `
			${header(c.card_index, c.brand)}
			${heroBlock(c.hero_title, c.hero_subtitle)}
			<div class="card-body">
				<div class="glass glass-accent hero-panel hero-panel--modes">
					<div class="hero-value-row">
						${heroIcon}
						<div class="hero-value">${fmtInt(c.hero_value || 0)}</div>
					</div>
					<div class="hero-caption">${esc(heroCaption)}</div>
				</div>
				${marathonSection}
				${modSection}
				${endlessSection}
				${factPanel(c.card_fact, L)}
			</div>
			${footer(c.footer_site, c.footer_date)}
		`;
	}

	const renderers = {
		overview: renderOverview,
		statistics: renderStatistics,
		music: renderMusic,
		records: renderRecords,
		play_modes: renderPlayModes,
	};

	const fn = renderers[CARD.card_id];
	root.innerHTML = fn ? fn(CARD) : `<div class="card-hero-title">—</div>`;
})();
