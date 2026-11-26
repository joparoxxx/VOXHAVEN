# Voxhaven foundation
Fresh Godot 4.5.1 project, no legacy code. Asset catalog paths serve as stable initial registry keys; semantic gameplay IDs will be introduced separately. The lab displays four representative models, reports animation names and attempts idle playback. Mouse drag/wheel and touch drag/magnify are initial camera controls; Android gesture behavior needs device testing.

Run with Godot 4:
```
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/registry_test.gd
godot --headless --path . -- --smoke
```
These checks must pass before claiming integration complete. Android export configuration and device profiling are pending. No gameplay simulation yet.

## Voxel data foundation
Seeded terrain, six biome classifications, caves, ores, chunk data and in-memory edits. Rendering, streaming, safe spawn, collision and persistence are not implemented yet. Run `godot --headless --path . --script res://tests/voxel_world_test.gd`.

## World rendering prototype
Main scene now opens the seeded world. Exposed-face indexed meshes, vertex-color placeholder materials, 3×3 chunk window, one synchronous chunk build per frame, trimesh collision, pan/zoom and queued edit rebuilds. Existing asset lab remains separately runnable. Texture atlas, background generation, persistence and mobile profiling remain pending. CI adds mesh and world smoke tests.

## Interactive world increment
Mine/place controls use terrain raycasts (right click or touch tap); placement uses dirt. Manual Save writes versioned seed and edits to user storage, and startup restores them. Persistence round-trip test added. Texture integration, safe spawn selection, background generation and decorations remain pending. Touch and interactive collision need device testing.
