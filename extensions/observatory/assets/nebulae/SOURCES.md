# Nebula sources and reuse record
Verified 2026-09-22. These are downloaded source assets, not AI-generated astronomy photographs.

## Photographs: CC BY 4.0

[ESA/Hubble reuse policy](https://esahubble.org/copyright/) explicitly permits reuse and sale of artwork with visible, unaltered credits. [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) permits commercial sharing and adaptation with attribution, a license link and notice of modifications. No extra restrictions are imposed on these source assets by Solmere.

| File | Official image page | Exact credit |
| --- | --- | --- |
| orion.jpg | [Orion, heic0601a](https://esahubble.org/images/heic0601a/) | NASA, ESA, M. Robberto (Space Telescope Science Institute/ESA) and the Hubble Space Telescope Orion Treasury Project Team |
| pillars.jpg | [Pillars, heic1501a](https://esahubble.org/images/heic1501a/) | NASA, ESA/Hubble and the Hubble Heritage Team |

Downloads, byte-for-byte as provided:
- https://cdn.esahubble.org/archives/images/publicationjpg/heic0601a.jpg
- https://cdn.esahubble.org/archives/images/publicationjpg/heic1501a.jpg

Treatment: original JPGs remain unchanged. The Orion photograph is retained as a provenance asset only; it is not promoted to a 3D object in the telescope. Pillars supplies an observed photograph's color projection onto separately supplied 3D geometry. Captures retain visible source credits and a modification notice.

## Existing 3D geometry

- **eta_carinae.stl:** [NASA Eta Carinae Homunculus Nebula](https://science.nasa.gov/3d-resources/eta-carinae-homunculus-nebula/). Credit: NASA / NASA 3D Resources.
  Download: https://assets.science.nasa.gov/content/dam/science/cds/3d/resources/printable/eta-carinae-homunculus-nebula/Eta%20Carinae%20Homunculus%20Nebula.stl
- **pillars.stl:** [NASA Pillars of Creation 3D model](https://science.nasa.gov/asset/hubble/pillars-of-creation-3d-model/), distributed through the official [Chandra 3D resource catalog](https://chandra.si.edu/resources/illustrations/3d_files.html).
  Credit: NASA's Universe of Learning, Leah Hustak (STScI), Ralf Crawford (STScI).
  Download: https://chandra.si.edu/deadstar/images/3d_files/m16.stl

Reuse basis: [NASA 3D Resources](https://github.com/nasa/NASA-3D-Resources) describes its assets as free and without copyright and links its [media guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/). [Chandra's materials policy](https://chandra.si.edu/photo/image_use.html) asserts no copyright over its NASA/SAO material and points to NASA's guidelines. The selected pages do not mark these models as excluded third-party commercial-restricted content. Keep the supplied credits; NASA/SAO/ESA/STScI do not endorse Solmere. Logos, recognizable people and audio/music from these sites are not included.

Treatment: tools/build_nebula_models.gd samples the imported STL surfaces with area weighting into 120,000 world-space samples plus continuous triangle surfaces each. Coordinates are reoriented and uniformly normalized. For Pillars, the printer base and lower attachments below source Z=30 are cropped. Both use Solmere-authored gas rendering, edge diffusion and color; they are not scale-accurate scientific simulations. Original STLs remain available for reconstruction and audit.

## Source checksums (SHA-256)

- eta_carinae.stl: EA491B9AEA3E4D60ABD0EE5A3DD8D08DAF094F074F0A13ACAF0C9D3A0B3E1D5F
- pillars.stl: 1664503A7F3317B77B593B331D6FBBA5439A9FEC468259D0EF685F1944A849A6
- orion.jpg: DB35758ED21509A16974D0AD36383EE0DD515C88C806F83FD1A4AD5AD5AE1477
- pillars.jpg: 3DFCD16BB0A6CF11FB09D51D81686156D3A23401DEEF335A2613F5689992FF20

Generated .res files are native Godot geometry resources; they inherit their source terms. Do not relabel the sources as exclusively owned by this game. No SpaceX media was bundled.

## 2026-09-22 presentation revision

Original JPEG files remain unchanged. They are used for provenance and, for the Pillars model, as a restrained surface color reference only. The telescope list contains only geometry that is a published 3D model or an observation-constrained reconstruction; no photograph is stretched into a guessed depth field. Official models retain their continuous triangle geometry, with restrained surface emission and no decorative starfield. The selected source, treatment and full image credits remain visible and saved with photographs.

Science text is traced to the linked official sources in nebula_catalog.gd: Orion formation and Hubble mosaic history; M16 star formation, erosion and the 1995/infrared observations; Eta Carinae and the nineteenth-century Great Eruption.

## 2026-09-22 observed-model expansion

- `crab_observed.tscn`: the three NASA supplied STL parts (disc and two jets) from the Crab Nebula 3D Resources page, converted into native Godot geometry. NASA says the model uses Chandra X-ray information to represent the pulsar, ringed disk and opposing jets.
- `cygnus_observed.tscn`: Draco-decoded geometry from the original NASA GLB, retained as native Godot geometry because the runtime has no Draco extension. The NASA page identifies it as a Salvatore Orlando research simulation constrained by Chandra observations.
- `casa_observed.zip` / `casa_observed.tscn`: Chandra's public ASCII VTK layers converted to native Godot geometry by `tools/vtk_to_obj.py` and `tools/import_obj_models.gd`. Source text credits NASA, Smithsonian Astrophysical Observatory/Chandra X-ray Center, MIT and T. Delaney et al. Layer colours are structural labels, not natural-light colours.

These additions are displayed as observed-data or observation-constrained structures. The viewer no longer applies a photographic depth projection to the official models. Where a scientific model is a simulation, the UI identifies it as such; it is not presented as a scale-accurate physical simulation.

The two original Draco-compressed GLBs are retained with Godot's `keep` importer.
Runtime references use the native `*_observed.tscn` conversions above; importing
the archival GLBs as scenes would require a Draco extension that is not bundled.
This preserves their original bytes and provenance without a broken cold import.
