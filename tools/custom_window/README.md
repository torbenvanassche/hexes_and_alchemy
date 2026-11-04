# Draggable windows

Inherit `base_window.tscn` for a new service window. Add a reusable page scene under
`NinePatchRect/VBoxContainer/contentPanel` and assign the root's **Content** property.
The legacy node names are retained so existing inherited scenes stay compatible.
Keep game-specific page logic in the page script rather than the window frame.

## Appearance

The root's **Appearance** resource controls the theme, optional frame StyleBox,
header color/height, title alignment/size, button and icon sizes, content margins,
and lock icons. Edit `default_appearance.tres` for shared defaults or duplicate it
for a family of windows. `journal_appearance.tres` demonstrates a centered title
and taller header. `themes/game_theme.tres` defines `WindowAction` and
`JournalContents` variations. SVG control icons live under `sprites/ui/line/`.
`WindowFrame` and `HudPanel` supply gold outlines; `JournalShortcut` keeps its full
outline in every button state. Separators use line styles, and scrollbars have
dedicated track/thumb styles with explicit minimum widths.
Call `apply_appearance()` after changing the resource at runtime.

## Extension slots

- **content_panel / set_content(page)**: the main page. Replacing a page detaches
  the old page; the caller owns freeing it or keeping it for reuse.
- **header_actions**: add optional controls before the lock/close buttons in an
  inherited scene. Reserve additional title space if adding more actions.
- **footer / set_footer(page)**: optional bottom content; hidden by default.
  Replacing footer content detaches it with the same ownership rule.
- **change_title** signal: accepts a translation key or literal title.

Use `request_fit_to_content()` after dynamic content changes. Scroll containers
inside the page keep long lists from expanding the frame. `store_position`
retains dragged position, `resizable` enables edge handles, and `can_lock` exposes
the keep-open control. A lock prevents Escape/shortcut closing; the explicit X
always closes and clears the lock.

The guild journal (`scenes/ui/hub_window.tscn`) composes reusable project,
commission, inventory, and notes pages with a contents column. Its existing
`projects`, `operations`, and `inventory` tab IDs remain valid for gameplay callers.

UI dimensions retain their original pixel size as the screen resolution changes.
The Stores grid derives its column count from the available page width and
100px minimum slot size, then fills the width with square slots.
