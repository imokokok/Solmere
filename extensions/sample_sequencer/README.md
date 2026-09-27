# Sample Sequencer

An additive record-shop editor for Soulmere. It keeps the existing four-track
studio intact and opens from its `格子音序器` button.

- Edits one 16-step bar at 78 BPM.
- Uses fixed C3, D3, E3, G3 and A3 melody lanes.
- Renders four bars before entering the existing VisualRoom and PressingTable.
- Stores its draft separately under `minigame_drafts.sound_sequencer`.
- Uses synthesized placeholder audio; collected samples can replace the source
  cache later without changing the pressing workflow.
