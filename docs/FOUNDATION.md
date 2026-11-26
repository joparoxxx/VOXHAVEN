# Voxhaven foundation
Fresh Godot 4 project, no legacy code. Asset catalog paths serve as stable initial registry keys; semantic gameplay IDs will be introduced separately. The lab displays four representative models, reports animation names and attempts idle playback. Mouse drag/wheel and touch drag/magnify are initial camera controls; Android gesture behavior needs device testing.

Run with Godot 4:
```
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/registry_test.gd
godot --headless --path . -- --smoke
```
These checks must pass before claiming integration complete. Android export configuration and device profiling are pending. No gameplay simulation yet.
