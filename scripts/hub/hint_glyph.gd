## K-01, nothing a kid has to read: the chooser hint is a picture, not words. The small centre
## button of the pad (Select / View: a pill with two little overlapping windows) next to a pair of
## round "swap" arrows in the player's colour. Keyboard players (no pad) see a keycap instead: Tab
## (an arrow to a bar) for P1, slash for P2. Drawn from an SVG built here, so no asset file.
class_name HintGlyph
extends RefCounted

enum Kind { SELECT, TAB, SLASH }

const INK := "#2b2140"
const CREAM := "#fff4dc"
const SIZE := Vector2i(256, 128)

static var _cache := {}


static func texture(kind: Kind, player_color: Color) -> Texture2D:
	var key := "%d/%s" % [kind, player_color.to_html(false)]
	if not _cache.has(key):
		var img := Image.new()
		if img.load_svg_from_string(svg(kind, player_color)) != OK:
			return null
		img.generate_mipmaps()
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


static func svg(kind: Kind, player_color: Color) -> String:
	var button := ""
	match kind:
		Kind.SELECT:   # the pad's small centre button: a pill with the two-windows View mark
			button = ('<rect x="12" y="28" width="104" height="72" rx="36" fill="{ink}" stroke="{cream}" stroke-width="8"/>'
				+ '<rect x="40" y="44" width="30" height="24" rx="4" fill="none" stroke="{cream}" stroke-width="6"/>'
				+ '<rect x="56" y="58" width="30" height="24" rx="4" fill="{cream}"/>')
		Kind.TAB:      # a keycap with an arrow running into a bar
			button = ('<rect x="16" y="20" width="96" height="88" rx="18" fill="{ink}" stroke="{cream}" stroke-width="8"/>'
				+ '<line x1="34" y1="64" x2="78" y2="64" stroke="{cream}" stroke-width="9" stroke-linecap="round"/>'
				+ '<polygon points="76,48 94,64 76,80" fill="{cream}"/>'
				+ '<line x1="98" y1="44" x2="98" y2="84" stroke="{cream}" stroke-width="7" stroke-linecap="round"/>')
		Kind.SLASH:    # a keycap with a slash
			button = ('<rect x="16" y="20" width="96" height="88" rx="18" fill="{ink}" stroke="{cream}" stroke-width="8"/>'
				+ '<line x1="76" y1="40" x2="52" y2="88" stroke="{cream}" stroke-width="10" stroke-linecap="round"/>')
	# round "swap" arrows: you become somebody else
	var swap := ('<circle cx="192" cy="64" r="50" fill="{ink}" stroke="{cream}" stroke-width="6"/>'
		+ '<path d="M160 52.4 A34 34 0 0 1 224 52.4" fill="none" stroke="{col}" stroke-width="10" stroke-linecap="round"/>'
		+ '<polygon points="229,66 234,48 214,55" fill="{col}"/>'
		+ '<path d="M224 75.6 A34 34 0 0 1 160 75.6" fill="none" stroke="{col}" stroke-width="10" stroke-linecap="round"/>'
		+ '<polygon points="155,62 150,80 170,73" fill="{col}"/>')
	var body := (button + swap).format({"ink": INK, "cream": CREAM, "col": "#" + player_color.lightened(0.15).to_html(false)})
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % [
		SIZE.x, SIZE.y, SIZE.x, SIZE.y, body]
