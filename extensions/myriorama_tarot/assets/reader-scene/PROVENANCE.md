# Reader room assets

Created 2026-09-27 with the built-in image generation tool (not the CLI/API fallback). The supplied Tarot & Things shop illustration was a composition/style reference, not a flattened playable screen. All text, cards, controls, characters, and interaction are separate runtime nodes.

`tarot-reader-original.png` is the user's original transparent PNG, copied without repainting, cropping or pixel edits. SHA256: `0B8D993900099B1FC82E1C4692D5B30C25F59E4F0053C99E3F917D6DE8A3C283`.

## Final prompt set / asset specification

Shared direction: stylized-concept game illustration; match the supplied soft, flat hand-painted gouache tarot shop reference and lavender/navy/old-gold palette. Simplify detail, broad painted shapes, restrained texture, no photorealism or 3D rendering. No lettering, UI, buttons, baked-in character or cards. Deliver independent compositing layers. Preserve real alpha where requested; no painted checkerboard or white matte.

- `room-backdrop-v2.png`: a front-facing seated view of a quiet navy room, central rectangular window overlooking a simplified coastal village at dusk, empty foreground; no table, curtains, person, clutter or controls.
- `curtains-v2.png`: matching paired navy curtains with broad graceful folds and sparse old-gold edging; clear open center; independent transparent overlay; no room or scenery painted behind them.
- `tabletop-v2.png`: matching dark navy tarot cloth and tabletop, **straight horizontal rear edge**, no trapezoid or tilted camera; sparse gold perimeter decoration, large quiet empty play area; upper area transparent; no cards, candles, hands or text.
- `candle-v2.png`: one small cream pillar candle in an old-gold saucer, simplified gouache shapes matching the room; isolated on actual transparency; no large halo, background or extra objects.
- `speech-bubble-v2.png`: a blank softly irregular rounded cream speech balloon with a small lower-right tail and restrained old-gold edge, matching the reference's hand-painted paper language; transparent outside; no text, symbols or shadow rectangle.

Generated alpha channels are retained. The engine only positions/scales layers and supplies gentle actual 2D lighting; it does not procedurally replace the requested background/curtain/table/candle/bubble artwork. Original Rider-Waite-inspired card faces, guide faces and shared card back remain unchanged.

Selected generation IDs: room `529ec305-a9f0-41d4-afa8-9016182d755c`, curtains `14fa5d6a-cb16-44a8-a1c4-4f3b05891c3a`, table `b6c008ad-b523-4a30-a7a6-d5143044c277`, candle `d76d07af-01ec-491a-9927-6d43a39be7c6`, bubble `cfbe429d-fb2a-4867-bc5d-6fb8bbfcc8a7`.
