#!/usr/bin/env python3
"""Render a theme's app files from themes/<name>/palette.json.

Stdlib only; outputs are committed next to the palette. palette.json is the single
source of truth for colour, so every app file here is regenerated, never hand-edited.
"""
import json
import re
import shutil
import sys
import tomllib
from pathlib import Path

FONT = {"family": "Noto Sans", "size": 12, "icons": "Phosphor", "iconsFill": "Phosphor-Fill"}
RADIUS = 8

# QML reserves on<Capital> identifiers for signal handlers, so M3's on* tokens get a Fg suffix.
SHELL_TOKENS = {
    "surface": "surface", "surfaceContainerLow": "surfaceContainerLow", "surfaceContainer": "surfaceContainer",
    "surfaceContainerHigh": "surfaceContainerHigh", "surfaceContainerHighest": "surfaceContainerHighest",
    "fg": "onSurface", "fgVariant": "onSurfaceVariant", "outline": "outline", "outlineVariant": "outlineVariant",
    "primary": "primary", "primaryFg": "onPrimary", "primaryContainer": "primaryContainer",
    "primaryContainerFg": "onPrimaryContainer", "error": "error",
}


def shell_json(palette):
    colors = {k: palette["m3"][v] for k, v in SHELL_TOKENS.items()}
    colors["success"] = palette["ansi"]["green"]
    colors["warning"] = palette["ansi"]["yellow"]
    return json.dumps({"font": FONT, "radius": RADIUS, "colors": colors}, indent=2) + "\n"


def ron(colour):
    return f'"{colour}ff"'


def builder_ron(palette):
    m3, ansi, extra, tones = palette["m3"], palette["ansi"], palette["extra"], palette["neutralTones"]
    neutrals = "".join(f"        neutral_{i}: {ron(t)},\n" for i, t in enumerate(tones))
    accents = {
        "blue": m3["primary"], "indigo": extra["indigo"], "purple": extra["purple"], "pink": extra["pink"],
        "red": ansi["red"], "orange": extra["orange"], "yellow": ansi["yellow"], "green": ansi["green"],
        "warm_grey": m3["onSurfaceVariant"],
    }
    accent_lines = "".join(f"        accent_{k}: {ron(v)},\n" for k, v in accents.items())
    ext = {"warm_grey": m3["outline"], "orange": extra["orange"], "yellow": ansi["yellow"],
           "blue": ansi["cyan"], "purple": extra["purple"], "pink": extra["pink"], "indigo": extra["indigo"]}
    ext_lines = "".join(f"        ext_{k}: {ron(v)},\n" for k, v in ext.items())
    return f"""(
    palette: Dark((
        name: "{palette["name"]}",
        bright_red: {ron(ansi["brightRed"])},
        bright_green: {ron(ansi["brightGreen"])},
        bright_orange: {ron(extra["orange"])},
        gray_1: {ron(m3["surface"])},
        gray_2: {ron(m3["surfaceContainer"])},
{neutrals}{accent_lines}{ext_lines}    )),
    spacing: (space_none: 0, space_xxxs: 4, space_xxs: 8, space_xs: 12, space_s: 16, space_m: 24, space_l: 32, space_xl: 48, space_xxl: 64, space_xxxl: 128),
    corner_radii: (radius_0: (0.0, 0.0, 0.0, 0.0), radius_xs: (4.0, 4.0, 4.0, 4.0), radius_s: (8.0, 8.0, 8.0, 8.0), radius_m: (16.0, 16.0, 16.0, 16.0), radius_l: (32.0, 32.0, 32.0, 32.0), radius_xl: (160.0, 160.0, 160.0, 160.0)),
    neutral_tint: Some({ron(m3["onSurface"])}),
    bg_color: Some({ron(m3["surface"])}),
    primary_container_bg: Some({ron(m3["surfaceContainerLow"])}),
    secondary_container_bg: Some({ron(m3["surfaceContainer"])}),
    text_tint: Some({ron(m3["onSurface"])}),
    accent: Some({ron(m3["primary"])}),
    success: Some({ron(ansi["green"])}),
    warning: Some({ron(ansi["yellow"])}),
    destructive: Some({ron(m3["error"])}),
    frosted: Medium,
    gaps: (0, 8),
    active_hint: 1,
    window_hint: Some({ron(m3["primary"])}),
    frosted_windows: false,
    frosted_system_interface: false,
    frosted_panel: false,
    frosted_applets: false,
    frosted_maximized_apps: false,
)
"""


ANSI_ORDER = ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
              "brightBlack", "brightRed", "brightGreen", "brightYellow", "brightBlue", "brightMagenta", "brightCyan", "brightWhite")


def ghostty(palette):
    m3, ansi = palette["m3"], palette["ansi"]
    lines = [f"palette = {i}={ansi[name]}" for i, name in enumerate(ANSI_ORDER)]
    lines += ["", f"background = {m3['surface']}", f"foreground = {m3['onSurface']}",
              f"cursor-color = {m3['primary']}", f"cursor-text = {m3['onPrimary']}",
              f"selection-background = {m3['surfaceContainerHighest']}", f"selection-foreground = {m3['onSurface']}"]
    return "\n".join(lines) + "\n"


def btop(palette):
    m3, ansi = palette["m3"], palette["ansi"]
    graph = lambda a, b, c: {"start": a, "mid": b, "end": c}
    values = {
        "main_bg": m3["surface"], "main_fg": m3["onSurface"], "title": m3["onSurface"], "hi_fg": m3["primary"],
        "selected_bg": m3["surfaceContainerHighest"], "selected_fg": m3["primary"], "proc_misc": m3["onSurfaceVariant"],
        "cpu_box": m3["outlineVariant"], "mem_box": m3["outlineVariant"], "net_box": m3["outlineVariant"],
        "proc_box": m3["outlineVariant"], "div_line": m3["outlineVariant"],
    }
    gradients = {
        "temp": graph(ansi["green"], ansi["yellow"], ansi["red"]),
        "cpu": graph(ansi["blue"], ansi["cyan"], ansi["magenta"]),
        "free": graph(ansi["green"], ansi["green"], ansi["brightGreen"]),
        "cached": graph(ansi["cyan"], ansi["cyan"], ansi["brightCyan"]),
        "available": graph(ansi["yellow"], ansi["yellow"], ansi["brightYellow"]),
        "used": graph(ansi["red"], ansi["red"], ansi["brightRed"]),
        "download": graph(ansi["blue"], ansi["blue"], ansi["brightBlue"]),
        "upload": graph(ansi["magenta"], ansi["magenta"], ansi["brightMagenta"]),
    }
    for name, g in gradients.items():
        values.update({f"{name}_{k}": v for k, v in g.items()})
    return "".join(f'theme[{k}]="{v}"\n' for k, v in values.items())


def vicinae(palette):
    m3, ansi, extra = palette["m3"], palette["ansi"], palette["extra"]
    return f"""[meta]
version = 1
name = "Ikigai"
description = "Ikigai's desktop palette: near-black warm greys with the wallpaper's blue."
variant = "dark"

[colors.core]
background = "{m3["surface"]}"
foreground = "{m3["onSurface"]}"
secondary_background = "{m3["surfaceContainerLow"]}"
border = "{m3["outlineVariant"]}"
accent = "{m3["primary"]}"

[colors.accents]
blue = "{m3["primary"]}"
green = "{ansi["green"]}"
magenta = "{ansi["magenta"]}"
orange = "{extra["orange"]}"
purple = "{extra["purple"]}"
red = "{ansi["red"]}"
yellow = "{ansi["yellow"]}"
cyan = "{ansi["cyan"]}"

[colors.list.item.selection]
background = "{m3["surfaceContainerHigh"]}"
secondary_background = "{m3["surfaceContainerHighest"]}"

[colors.grid.item]
background = "{m3["surfaceContainer"]}"
"""


def gtk_css(palette):
    m3, ansi = palette["m3"], palette["ansi"]
    colours = {
        "window_bg_color": m3["surfaceContainerLow"], "window_fg_color": m3["onSurface"],
        "view_bg_color": m3["surface"], "view_fg_color": m3["onSurface"],
        "headerbar_bg_color": m3["surfaceContainer"], "headerbar_fg_color": m3["onSurface"],
        "headerbar_border_color": m3["onSurface"], "headerbar_backdrop_color": m3["surfaceContainerLow"],
        "headerbar_shade_color": "rgba(0, 0, 0, 0.36)", "headerbar_darker_shade_color": "rgba(0, 0, 0, 0.9)",
        "sidebar_bg_color": m3["surfaceContainer"], "sidebar_fg_color": m3["onSurface"],
        "sidebar_backdrop_color": m3["surfaceContainerLow"], "sidebar_border_color": "rgba(0, 0, 0, 0.36)",
        "sidebar_shade_color": "rgba(0, 0, 0, 0.25)",
        "secondary_sidebar_bg_color": m3["surfaceContainerLow"], "secondary_sidebar_fg_color": m3["onSurface"],
        "secondary_sidebar_backdrop_color": m3["surface"], "secondary_sidebar_border_color": "rgba(0, 0, 0, 0.36)",
        "secondary_sidebar_shade_color": "rgba(0, 0, 0, 0.25)",
        "card_bg_color": m3["surfaceContainerHigh"], "card_fg_color": m3["onSurface"], "card_shade_color": "rgba(0, 0, 0, 0.36)",
        "dialog_bg_color": m3["surfaceContainerHigh"], "dialog_fg_color": m3["onSurface"],
        "popover_bg_color": m3["surfaceContainerHigh"], "popover_fg_color": m3["onSurface"], "popover_shade_color": "rgba(0, 0, 0, 0.25)",
        "thumbnail_bg_color": m3["surfaceContainerHighest"], "thumbnail_fg_color": m3["onSurface"],
        "shade_color": "rgba(0, 0, 0, 0.36)", "scrollbar_outline_color": "rgba(0, 0, 0, 0.5)",
        "accent_bg_color": m3["primaryContainer"], "accent_fg_color": m3["onPrimaryContainer"], "accent_color": m3["primary"],
        "destructive_bg_color": m3["errorContainer"], "destructive_fg_color": m3["onErrorContainer"], "destructive_color": m3["error"],
        "error_bg_color": m3["errorContainer"], "error_fg_color": m3["onErrorContainer"], "error_color": m3["error"],
        "success_bg_color": ansi["green"], "success_fg_color": m3["surface"], "success_color": ansi["green"],
        "warning_bg_color": ansi["yellow"], "warning_fg_color": m3["surface"], "warning_color": ansi["yellow"],
    }
    return "".join(f"@define-color {k} {v};\n" for k, v in colours.items())


# Cursors: Bibata Modern's SVGs (cursors/bibata, GPL-3) with its placeholder colours swapped
# for the palette's, laid out as a scalable cursor theme (cursors_scalable/<name>/metadata.json,
# the KDE/libXcursor SVG format cosmic-comp renders itself). ikigai-theme-set rasterises the
# same SVGs into Xcursor files for the toolkits that only read those.
CURSOR_SRC = Path(__file__).resolve().parent.parent / "cursors" / "bibata"
CURSOR_OWN = CURSOR_SRC.parent / "ikigai"  # Ikigai's own shapes, drawn in Bibata's idiom
CURSOR_CANVAS = 256  # Bibata draws on a 256-unit canvas; hotspots.toml is in those units
CURSOR_DELAY = 40    # ms per animation frame, upstream's x11_delay


def cursor_colours(palette):
    m3, ansi, extra = palette["m3"], palette["ansi"], palette["extra"]
    return {
        "#00FF00": m3["surface"],    # body
        "#0000FF": m3["onSurface"],  # outline
        "#FF0000": m3["surface"],    # the wait disc: the body's colour, as in Bibata Classic
        # Bibata's four Google colours: the wait pie, left_ptr_watch's, and the four corners
        "#32A0DA": ansi["blue"], "#4FADDF": ansi["blue"],
        "#7EBA41": ansi["green"], "#96C865": ansi["green"],
        "#F05024": ansi["red"], "#F1613A": ansi["red"],
        "#FCB813": ansi["yellow"], "#FDBE2A": ansi["yellow"],
        # badges
        "#FE0000": m3["error"],                    # circle, crosshair, crossed_circle, dnd_no_drop
        "#06B231": ansi["green"],                  # copy, dnd-copy
        "#0A6857": ansi["cyan"],                   # pin
        "#179DD8": m3["primary"],                  # pointer-move
        "#5F3BE4": extra["purple"],                # context-menu
        "#606060": m3["outline"],                  # link, dnd-link
        "#2C2C2C": m3["surfaceContainerHighest"],  # person
        "#F27400": extra["orange"],                # dnd-ask
        '"white"': f'"{m3["onSurface"]}"',         # badge glyphs, the outline's colour
    }


def cursors(palette, out):
    colours = {k.upper(): v for k, v in cursor_colours(palette).items()}
    pattern = re.compile("|".join(re.escape(k) for k in colours), re.IGNORECASE)
    recolour = lambda svg: pattern.sub(lambda m: colours[m.group(0).upper()], svg)
    table = tomllib.loads((CURSOR_SRC / "hotspots.toml").read_text())["cursors"]
    defaults = table.pop("fallback_settings")
    entries = [(CURSOR_SRC, e) for e in table.values()]
    own = tomllib.loads((CURSOR_OWN / "hotspots.toml").read_text())["cursors"]
    entries += [(CURSOR_OWN, e) for e in own.values()]
    if out.exists():
        shutil.rmtree(out)
    scalable = out / "cursors_scalable"
    aliases = []
    for src, entry in entries:
        name = entry["x11_name"]
        stem = entry["png"].removesuffix(".png")
        if stem.endswith("-*"):  # animated: a directory of frames
            frames = sorted((src / "svg" / stem[:-2]).glob("*.svg"))
        else:
            frames = [src / "svg" / f"{stem}.svg"]
        meta = []
        for frame in frames:
            (scalable / name).mkdir(parents=True, exist_ok=True)
            (scalable / name / frame.name).write_text(recolour(frame.read_text()))
            m = {"filename": frame.name, "nominal_size": CURSOR_CANVAS,
                 "hotspot_x": entry.get("x_hotspot", defaults["x_hotspot"]),
                 "hotspot_y": entry.get("y_hotspot", defaults["y_hotspot"])}
            if len(frames) > 1:
                m["delay"] = CURSOR_DELAY
            meta.append(m)
        (scalable / name / "metadata.json").write_text(json.dumps(meta, indent=2) + "\n")
        aliases += [(alias, name) for alias in entry.get("x11_symlinks", [])]
    for alias, name in sorted(aliases):
        (scalable / alias).symlink_to(name)
    (out / "cursor.theme").write_text(
        f"[Icon Theme]\nName={out.name}\nComment=Bibata Modern in the {palette['name']} palette\n")
    shutil.copy(CURSOR_SRC / "LICENSE", out / "LICENSE")
    return len(entries), len(aliases)


OUTPUTS = {
    "shell.json": shell_json,
    "cosmic/builder.ron": builder_ron,
    "ghostty/ikigai": ghostty,
    "btop/ikigai.theme": btop,
    "vicinae/ikigai.toml": vicinae,
    "gtk/gtk.css": gtk_css,
}


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: theme-build.py themes/<name>")
    theme = Path(sys.argv[1])
    palette = json.loads((theme / "palette.json").read_text())
    for rel, render in OUTPUTS.items():
        out = theme / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(render(palette))
        print(f"wrote {out}")
    shapes, aliases = cursors(palette, theme / "cursors" / "Ikigai")
    print(f"wrote {theme / 'cursors' / 'Ikigai'} ({shapes} cursors, {aliases} aliases)")


if __name__ == "__main__":
    main()
