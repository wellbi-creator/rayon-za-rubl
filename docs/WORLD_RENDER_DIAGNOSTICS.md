# Temporary world-render diagnostics

This diagnostic overlay is temporary and exists to investigate the report that the mobile Web build displays the interface but not the isometric world.

The bottom-left line reports:
- `draw`: number of times the `DistrictWorld._draw()` callback has run since scene startup. A value that remains at 0 suggests the world draw callback is not being reached.
- `visible`: whether the world node is visible in the scene tree.
- `viewport`: viewport dimensions reported by Godot.
- `camera`: world-space camera position.
- `zoom`: camera zoom.
- `current`: whether this Camera2D is the active camera.

The overlay is non-interactive and ignores pointer input. It does not change world rendering, camera movement, gameplay, or save data. Remove the label, status method, and draw counter after diagnosis.

## Mobile test

Open the published build on the iPhone, reload once, and read the diagnostic line at the bottom-left. Report the full line and whether any map tiles are visible. Do not merge this diagnostic PR until its checks pass and the diagnosis is reviewed.
