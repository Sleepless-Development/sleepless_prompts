import { applyTheme, THEMES } from "./theme.js";

const hud = document.getElementById("hud");
const groups = new Map();
const isBrowser = !window.invokeNative;
const isAd = /ad(?:-[a-z0-9]+)?\.html$/i.test(location.pathname);

function fetchNui(event, data = {}) {
	if (isBrowser) return Promise.resolve();
	const resource = window.GetParentResourceName ? GetParentResourceName() : "sleepless_prompts";
	return fetch(`https://${resource}/${event}`, {
		method: "POST",
		headers: { "Content-Type": "application/json; charset=UTF-8" },
		body: JSON.stringify(data),
	});
}

function el(tag, className) {
	const node = document.createElement(tag);
	if (className) node.className = className;
	return node;
}

function slotFor(position) {
	let slot = hud.querySelector(`.slot[data-pos="${position}"]`);
	if (!slot) {
		slot = el("div", "slot");
		slot.dataset.pos = position;
		hud.appendChild(slot);
	}
	return slot;
}

function originTranslate(origin) {
	switch (origin) {
		case "top-left":
			return "0 0";
		case "top-center":
			return "-50% 0";
		case "top-right":
			return "-100% 0";
		case "middle-left":
			return "0 -50%";
		case "middle-right":
			return "-100% -50%";
		case "bottom-left":
			return "0 -100%";
		case "bottom-center":
			return "-50% -100%";
		case "bottom-right":
			return "-100% -100%";
		default:
			return "-50% -50%";
	}
}

function separatorText(kind) {
	if (kind === "dot") return "·";
	return "/";
}

function renderIcons(target, prompt) {
	const icons = prompt.icons || [];
	const fallbacks = prompt.fallbacks || [];
	const count = Math.max(icons.length, fallbacks.length);

	for (let i = 0; i < count; i++) {
		if (i > 0) {
			const plus = el("span", "icon-plus");
			plus.textContent = "+";
			target.appendChild(plus);
		}

		const src = icons[i];
		const fallback = fallbacks[i] || prompt.label;

		if (src) {
			const img = el("img", "icon");
			img.src = src;
			img.alt = fallback;
			img.addEventListener("error", () => {
				img.replaceWith(fallbackNode(fallback));
			});
			target.appendChild(img);
		} else {
			target.appendChild(fallbackNode(fallback));
		}
	}
}

function fallbackNode(text) {
	const node = el("span", "icon-fallback");
	node.textContent = String(text).slice(0, 4);
	return node;
}

function renderPrompt(prompt) {
	const item = el("div", "item");
	item.dataset.id = prompt.id;
	if (prompt.disabled) item.classList.add("is-disabled");
	if (prompt.active) item.classList.add("is-active");

	if (prompt.hold) {
		const prefix = prompt.holdPrefix || (isBrowser ? "Hold" : "");
		if (prefix) {
			const node = el("span", "hold-prefix");
			node.textContent = prefix;
			item.appendChild(node);
		}
	}

	const iconWrap = el("div", "icons");
	renderIcons(iconWrap, prompt);
	item.appendChild(iconWrap);

	const label = el("span", "label");
	label.textContent = prompt.label;
	item.appendChild(label);

	if (prompt.hold) {
		const hold = el("div", "hold");
		const fill = el("div", "hold-fill");
		if (!isBrowser || isAd) {
			fill.style.width = `${Math.max(0, Math.min(1, prompt.progress || 0)) * 100}%`;
		}
		hold.appendChild(fill);
		item.appendChild(hold);
	}

	return item;
}

function applyGroupChrome(node, data) {
	node.dataset.id = data.id;
	node.dataset.position = data.position;
	node.dataset.layout = data.layout || "row";
	node.dataset.align = data.align || "center";
	node.dataset.separator = data.separator || "slash";
	node.style.order = String(data.order || 0);
	if (data.persistOnPause) node.dataset.persistPause = "";
	else delete node.dataset.persistPause;
	node.style.setProperty("--ox", `${data.offset?.x || 0}rem`);
	node.style.setProperty("--oy", `${data.offset?.y || 0}rem`);

	if (data.position === "custom" && data.custom) {
		const unit = (value) => (typeof value === "number" ? `${value}%` : value);
		node.style.setProperty("--cx", unit(data.custom.x));
		node.style.setProperty("--cy", unit(data.custom.y));
		node.style.translate = originTranslate(data.custom.origin);
	} else {
		node.style.removeProperty("--cx");
		node.style.removeProperty("--cy");
		node.style.removeProperty("translate");
		node.style.removeProperty("transform");
	}
}

function fillGroup(node, data) {
	applyGroupChrome(node, data);
	node.replaceChildren();
	const prompts = data.prompts || [];
	for (let i = 0; i < prompts.length; i++) {
		if (i > 0) {
			const sep = el("div", "sep");
			sep.textContent = separatorText(data.separator);
			node.appendChild(sep);
		}
		node.appendChild(renderPrompt(prompts[i]));
	}
}

function attachGroup(node, data) {
	const previousParent = node.parentNode;
	if (data.position === "custom") {
		hud.appendChild(node);
	} else {
		slotFor(data.position).appendChild(node);
	}
	if (
		previousParent &&
		previousParent !== node.parentNode &&
		previousParent.classList.contains("slot") &&
		previousParent.childElementCount === 0
	) {
		previousParent.remove();
	}
}

function detach(node) {
	const parent = node.parentNode;
	node.remove();
	if (parent && parent.classList.contains("slot") && parent.childElementCount === 0) {
		parent.remove();
	}
}

function fadeMs(node) {
	const raw = (getComputedStyle(node).transitionDuration || "").split(",")[0].trim();
	const value = Number.parseFloat(raw);
	if (Number.isNaN(value)) return 200;
	return raw.endsWith("ms") ? value : value * 1000;
}

function clearLeave(record) {
	if (record.leaveTimer) {
		window.clearTimeout(record.leaveTimer);
		record.leaveTimer = 0;
	}
	if (record.onLeaveEnd) {
		record.node.removeEventListener("transitionend", record.onLeaveEnd);
		record.onLeaveEnd = null;
	}
}

function mountGroup(data) {
	const existing = groups.get(data.id);
	if (existing?.node?.isConnected) {
		clearLeave(existing);
		existing.node.classList.remove("is-leaving", "is-entering");
		fillGroup(existing.node, data);
		attachGroup(existing.node, data);
		existing.data = data;
		return;
	}

	if (existing) {
		clearLeave(existing);
		groups.delete(data.id);
	}

	const node = el("div", "group");
	fillGroup(node, data);
	node.classList.add("is-entering");
	attachGroup(node, data);
	groups.set(data.id, { node, data });
	void node.offsetWidth;
	requestAnimationFrame(() => {
		if (!node.isConnected || node.classList.contains("is-leaving")) return;
		node.classList.remove("is-entering");
	});
}

function removeGroup(id) {
	const existing = groups.get(id);
	if (!existing?.node) return;

	const node = existing.node;
	if (node.classList.contains("is-leaving")) return;

	const finish = (event) => {
		if (event && event.target !== node) return;
		if (event && event.propertyName && event.propertyName !== "opacity") return;
		if (!node.classList.contains("is-leaving")) return;
		clearLeave(existing);
		if (groups.get(id) === existing) groups.delete(id);
		detach(node);
	};

	node.classList.remove("is-entering");
	node.classList.add("is-leaving");
	existing.onLeaveEnd = finish;
	node.addEventListener("transitionend", finish);
	existing.leaveTimer = window.setTimeout(finish, fadeMs(node) + 40);
}

function setGroups(list) {
	const keep = new Set();
	for (let i = 0; i < (list || []).length; i++) {
		keep.add(list[i].id);
		mountGroup(list[i]);
	}
	for (const id of Array.from(groups.keys())) {
		if (!keep.has(id)) removeGroup(id);
	}
}

function patchPrompt(payload) {
	const group = groups.get(payload.groupId);
	if (!group) return;
	const item = group.node.querySelector(`.item[data-id="${payload.promptId}"]`);
	if (!item) return;

	const patch = payload.patch || {};
	if (patch.disabled !== undefined) item.classList.toggle("is-disabled", !!patch.disabled);
	if (patch.active !== undefined) item.classList.toggle("is-active", !!patch.active);
	if (patch.progress !== undefined) {
		const fill = item.querySelector(".hold-fill");
		if (fill) fill.style.width = `${Math.max(0, Math.min(1, patch.progress)) * 100}%`;
	}
	if (patch.label) {
		const label = item.querySelector(".label");
		if (label) label.textContent = patch.label;
	}
}

function detectGamepad() {
  const pads = navigator.getGamepads ? navigator.getGamepads() : [];
  for (let i = 0; i < pads.length; i++) {
    const pad = pads[i];
    if (!pad || !pad.connected) continue;
    const id = String(pad.id || "").toLowerCase();
    if (
      id.includes("dualsense") ||
      id.includes("dualshock") ||
      id.includes("playstation") ||
      id.includes("sony") ||
      id.includes("054c") ||
      id.includes("ps5") ||
      id.includes("ps4") ||
      id.includes("wireless controller")
    ) {
      return "playstation";
    }
    if (id.includes("xbox") || id.includes("xinput") || id.includes("x-box") || id.includes("045e")) {
      return "xbox";
    }
  }
  return null;
}

function reportGamepad() {
  const gamepad = detectGamepad();
  if (gamepad) fetchNui("gamepadDetected", { gamepad });
}

function srgbToLin(channel) {
	const c = channel / 255;
	return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
}

function onAccentFor(r, g, b) {
	const luminance = 0.2126 * srgbToLin(r) + 0.7152 * srgbToLin(g) + 0.0722 * srgbToLin(b);
	return luminance > 0.28 ? "8, 11, 16" : "236, 241, 247";
}

function setColor(color) {
	const root = document.documentElement;
	if (!color) {
		root.style.removeProperty("--primary");
		root.style.removeProperty("--on-accent");
		root.style.removeProperty("--theme-color");
		return;
	}

	const r = Number(color[0]);
	const g = Number(color[1]);
	const b = Number(color[2]);
	const a = color[3] == null ? 255 : Number(color[3]);
	root.style.setProperty("--primary", `${r}, ${g}, ${b}`);
	root.style.setProperty("--on-accent", onAccentFor(r, g, b));
	root.style.setProperty("--theme-color", `rgb(${r}, ${g}, ${b}, ${a / 255})`);
}

function setIconSize(size) {
	if (size == null) return;
	document.documentElement.style.setProperty("--icon-size", `${size}rem`);
}

function setTheme(theme) {
	if (!theme) return;
	if (typeof theme === "string") {
		applyTheme(theme);
		return;
	}
	if (theme.theme) applyTheme(theme.theme);
	if (theme.color) setColor(theme.color);
	if (theme.iconSize) setIconSize(theme.iconSize);
	if (theme.ink) document.documentElement.style.setProperty("--ink", theme.ink);
	if (theme.surface) document.documentElement.style.setProperty("--surface", theme.surface);
	if (theme.text) document.documentElement.style.setProperty("--text", theme.text);
	if (theme.textMuted) document.documentElement.style.setProperty("--text-muted", theme.textMuted);
	if (theme.hairline) document.documentElement.style.setProperty("--hairline", theme.hairline);
	if (theme.primary) document.documentElement.style.setProperty("--primary", theme.primary);
	if (theme.error) document.documentElement.style.setProperty("--error", theme.error);
	if (theme.frost !== undefined) document.documentElement.style.setProperty("--panel-a", String(theme.frost));
}

const LAYOUTS = [
	{ id: "row", label: "Row" },
	{ id: "column", label: "Column" },
	{ id: "auto", label: "Auto" },
];

const SEPARATORS = [
	{ id: "slash", label: "Slash" },
	{ id: "line", label: "Line" },
	{ id: "dot", label: "Dot" },
	{ id: "none", label: "None" },
];

const POSITIONS = [
	{ id: "top-left", label: "TL" },
	{ id: "top-center", label: "TC" },
	{ id: "top-right", label: "TR" },
	{ id: "middle-left", label: "ML" },
	{ id: "center", label: "C" },
	{ id: "middle-right", label: "MR" },
	{ id: "bottom-left", label: "BL" },
	{ id: "bottom-center", label: "BC" },
	{ id: "bottom-right", label: "BR" },
];

const DEVICES = [
	{ id: "keyboard", label: "Keyboard" },
	{ id: "xbox", label: "Xbox" },
	{ id: "playstation", label: "PlayStation" },
];

const KEYBOARD_STYLES = [
	{ id: "white", label: "White" },
	{ id: "dark", label: "Dark" },
	{ id: "alt", label: "Alt" },
	{ id: "retro", label: "Retro" },
	{ id: "vintage", label: "Vintage" },
];

const GAMEPAD_STYLES = [
	{ id: "default", label: "Default" },
	{ id: "light", label: "Light" },
	{ id: "alt", label: "Alt" },
	{ id: "alt2", label: "Alt 2" },
	{ id: "retro", label: "Retro" },
];

const SCALES = [
	{ id: "0.8", label: "0.8" },
	{ id: "1", label: "1.0" },
	{ id: "1.2", label: "1.2" },
];

const preview = {
	theme: "modern",
	layout: "row",
	separator: "slash",
	position: "bottom-center",
	device: "xbox",
	style: "light",
	scale: "1",
	hidden: false,
};

function padSuffix(style) {
	if (!style || style === "default") return "";
	if (style === "alt2") return "_Alt_2";
	return `_${style.charAt(0).toUpperCase()}${style.slice(1)}`;
}

function keyboardIcon(letter, style) {
	const suffix = { white: "White", dark: "Dark", alt: "Alt", retro: "Retro", vintage: "Vintage" }[style] || "White";
	return `./icons/keyboard/${style}/T_${letter}_Key_${suffix}.webp`;
}

function xboxIcon(button, style) {
	return `./icons/xbox/${style}/T_X_${button}_White${padSuffix(style)}.webp`;
}

function playstationIcon(face, style) {
	return `./icons/playstation/${style}/T_P5_${face}${padSuffix(style)}.webp`;
}

function styleOptions() {
	return preview.device === "keyboard" ? KEYBOARD_STYLES : GAMEPAD_STYLES;
}

function defaultStyle(device) {
	return device === "keyboard" ? "white" : "light";
}

function alignFor(position) {
	if (position.includes("left")) return "start";
	if (position.includes("right")) return "end";
	return "center";
}

function layoutFor(position, layout) {
	if (layout && layout !== "auto") return layout;
	if (position === "middle-left" || position === "middle-right") return "column";
	return "row";
}

function vehiclePrompts() {
	const style = preview.style;
	if (preview.device === "keyboard") {
		return [
			{ id: "enter", label: "Enter", icons: [keyboardIcon("E", style)], fallbacks: ["E"] },
			{ id: "lock", label: "Lock", icons: [keyboardIcon("L", style)], fallbacks: ["L"] },
			{ id: "trunk", label: "Trunk", icons: [keyboardIcon("G", style)], fallbacks: ["G"] },
			{ id: "engine", label: "Engine", icons: [keyboardIcon("F", style)], fallbacks: ["F"], hold: true, active: true },
		];
	}
	if (preview.device === "playstation") {
		return [
			{ id: "enter", label: "Enter", icons: [playstationIcon("Cross", style)], fallbacks: ["✕"] },
			{ id: "lock", label: "Lock", icons: [playstationIcon("Square", style)], fallbacks: ["□"] },
			{ id: "trunk", label: "Trunk", icons: [playstationIcon("Circle", style)], fallbacks: ["○"] },
			{ id: "engine", label: "Engine", icons: [playstationIcon("Triangle", style)], fallbacks: ["△"], hold: true, active: true },
		];
	}
	return [
		{ id: "enter", label: "Enter", icons: [xboxIcon("A", style)], fallbacks: ["A"] },
		{ id: "lock", label: "Lock", icons: [xboxIcon("X", style)], fallbacks: ["X"] },
		{ id: "trunk", label: "Trunk", icons: [xboxIcon("B", style)], fallbacks: ["B"] },
		{ id: "engine", label: "Engine", icons: [xboxIcon("Y", style)], fallbacks: ["Y"], hold: true, active: true },
	];
}

function buildPreviewGroups() {
	const position = preview.position;
	const layout = layoutFor(position, preview.layout);
	const separator = preview.separator;
	const fallbackPosition = position === "top-right" ? "top-left" : "top-right";
	return [
		{
			id: "vehicle",
			position,
			layout,
			align: alignFor(position),
			separator,
			offset: { x: 0, y: 0 },
			prompts: vehiclePrompts(),
		}
	];
}

function refreshPreview() {
	document.documentElement.style.setProperty("--scale", preview.scale);
	if (preview.hidden) {
		setGroups([]);
		return;
	}
	setGroups(buildPreviewGroups());
}

function mountChoiceRow(parent, label, items, getActive, onPick, extraClass) {
	const row = el("div", "browser-row");
	const caption = el("span", "browser-dock-label");
	caption.textContent = label;
	row.appendChild(caption);

	const group = el("div", extraClass || "browser-group");
	const paint = () => {
		group.querySelectorAll("button").forEach((node) => {
			node.classList.toggle("is-active", node.dataset.id === getActive());
		});
	};

	items.forEach((item) => {
		const button = el("button");
		button.type = "button";
		button.textContent = item.label;
		button.dataset.id = item.id;
		if (item.title) button.title = item.title;
		button.addEventListener("click", () => {
			onPick(item.id);
			paint();
		});
		group.appendChild(button);
	});

	paint();
	row.appendChild(group);
	parent.appendChild(row);
	return { group, paint, row };
}

function fillChoiceGroup(group, items, getActive, onPick) {
	group.replaceChildren();
	items.forEach((item) => {
		const button = el("button");
		button.type = "button";
		button.textContent = item.label;
		button.dataset.id = item.id;
		button.addEventListener("click", () => {
			onPick(item.id);
			group.querySelectorAll("button").forEach((node) => {
				node.classList.toggle("is-active", node.dataset.id === item.id);
			});
		});
		group.appendChild(button);
	});
	group.querySelectorAll("button").forEach((node) => {
		node.classList.toggle("is-active", node.dataset.id === getActive());
	});
}

function mountBrowserDock() {
	const dock = document.getElementById("browser-dock");
	if (!dock) return;

	dock.hidden = false;
	dock.replaceChildren();

	mountChoiceRow(dock, "Theme", THEMES, () => preview.theme, (id) => {
		preview.theme = id;
		applyTheme(id);
		setColor(null);
	});

	mountChoiceRow(dock, "Layout", LAYOUTS, () => preview.layout, (id) => {
		preview.layout = id;
		refreshPreview();
	});

	mountChoiceRow(dock, "Separator", SEPARATORS, () => preview.separator, (id) => {
		preview.separator = id;
		refreshPreview();
	});

	mountChoiceRow(
		dock,
		"Position",
		POSITIONS.map((item) => ({ ...item, title: item.id })),
		() => preview.position,
		(id) => {
			preview.position = id;
			refreshPreview();
		},
		"browser-positions",
	);

	const styleRow = mountChoiceRow(dock, "Style", styleOptions(), () => preview.style, (id) => {
		preview.style = id;
		refreshPreview();
	});

	const deviceRow = mountChoiceRow(dock, "Device", DEVICES, () => preview.device, (id) => {
		preview.device = id;
		const allowed = styleOptions().some((item) => item.id === preview.style);
		if (!allowed) preview.style = defaultStyle(id);
		fillChoiceGroup(styleRow.group, styleOptions(), () => preview.style, (styleId) => {
			preview.style = styleId;
			refreshPreview();
		});
		refreshPreview();
	});

	dock.insertBefore(deviceRow.row, styleRow.row);

	mountChoiceRow(dock, "Scale", SCALES, () => preview.scale, (id) => {
		preview.scale = id;
		refreshPreview();
	});

	mountChoiceRow(
		dock,
		"Visible",
		[
			{ id: "show", label: "Show" },
			{ id: "hide", label: "Hide" },
		],
		() => (preview.hidden ? "hide" : "show"),
		(id) => {
			preview.hidden = id === "hide";
			refreshPreview();
		},
	);
}

window.addEventListener("message", (event) => {
	const { action, data } = event.data || {};
	switch (action) {
		case "setTheme":
			setTheme(data);
			break;
		case "setColor":
			setColor(data);
			break;
		case "setIconSize":
			setIconSize(data);
			break;
		case "setScale":
			document.documentElement.style.setProperty("--scale", String(data ?? 1));
			break;
		case "setGroups":
			setGroups(data || []);
			break;
		case "upsertGroup":
			mountGroup(data);
			break;
		case "removeGroup":
			removeGroup(data);
			break;
		case "patchPrompt":
			patchPrompt(data);
			break;
		case "setPaused":
			document.documentElement.classList.toggle("is-paused", !!data);
			break;
		case "detectGamepad":
			reportGamepad();
			break;
		default:
			break;
	}
});

window.addEventListener("load", () => {
	fetchNui("ready");
	reportGamepad();
});

window.addEventListener("gamepadconnected", reportGamepad);
window.addEventListener("gamepaddisconnected", reportGamepad);

if (isBrowser && !isAd) {
	document.documentElement.classList.add("browser");
	const params = new URLSearchParams(window.location.search);
	preview.theme = params.get("theme") || preview.theme;
	preview.layout = params.get("layout") || preview.layout;
	preview.separator = params.get("separator") || preview.separator;
	preview.position = params.get("position") || preview.position;
	preview.device = params.get("device") || preview.device;
	preview.style = params.get("style") || defaultStyle(preview.device);
	preview.scale = params.get("scale") || preview.scale;
	if (!styleOptions().some((item) => item.id === preview.style)) {
		preview.style = defaultStyle(preview.device);
	}
	applyTheme(preview.theme);
	mountBrowserDock();
	refreshPreview();
}
