# Soulmere Sample Sequencer Prototype

This is a self-contained Godot 4.7.2 prototype. It does not load or modify the
main Soulmere game, its save files, or the record-shop workbench.

## Run

1. Import `prototypes/sample-sequencer/project.godot` in Godot.
2. Press F6 or F5.
3. The default window is 1440×810; maximize it for a 1600×900 layout.

## Controls

- Rhythm/texture rows toggle on and off.
- C3, D3, E3, G3 and A3 rows cycle through off, 1, 2, 4 and 8 steps.
- Save/Load stores only this prototype's grid in `user://sequencer_draft.json`.

## Previous integration approach

The earlier experiment added one button to `StudioScreen.gd`. That button
instantiated the sequencer as an overlay, rendered four bars into an
`Arrangement`, and passed the result to the existing `VisualRoom` and
`PressingTable`. This prototype revision removes that hook and all runtime
dependencies so other authors' production code remains untouched.
