"""Import explicitly reviewed CC0 field recordings; never synthesizes sounds.

Requires numpy and soundfile. Downloads the public Ogg preview linked in the
source page (not the login-only original), checks CC0, retains provenance and
hashes, then trims, gain-matches, fades and crossfades recordings for the game.
Run: python tools/import_recorded_audio.py --cache <outside-project-directory>
"""
import argparse
import hashlib
import html
import json
import re
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np
import soundfile as sf

PROJECT = Path(__file__).resolve().parents[1]
DEST = PROJECT / "modules/restaurant/assets/audio/recorded"
LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"
# author, sound id, short recording description, clips: bank, start, seconds, loop
SOURCES = [
    ("Anthousai", 336613, "Raw egg cracked into a glass bowl", [("egg_crack", 0, 0, False)]),
    ("ciccarelli", 170416, "Eggs frying in oil", [("fry_egg", 12, 9, True), ("fry_egg", 30, 9, True)]),
    ("neilraouf", 464301, "Vegetables cooking in butter", [("fry_vegetable", 2, 6, True), ("fry_vegetable", 10, 6, True)]),
    ("colorsCrimsonTears", 547519, "Sausage frying in an oil-filled skillet", [("fry_meat", 1, 7, True)]),
    ("xenognosis", 137229, "Water boiling in a small pot", [("boil", 1, 10, True)]),
    ("andatha", 568112, "Boiling water recorded with Zoom H1n", [("boil", 3, 10, True)]),
    ("bittermelonheart", 560564, "Sauce simmering and stirring on stove", [("simmer_sauce", 5, 10, True), ("stir_sauce", 32, 0.8, False)]),
    ("leftovertunacasserole", 610255, "Tomato sauce bubbling", [("simmer_sauce", 1, 12, True)]),
    ("xenognosis", 137245, "Salt shaken inside plastic container", [("powder", 1, 4, True), ("powder", 5.5, 4, True)]),
    ("makemebad", 95740, "Dry seasoning shaken in plastic bottle", [("powder_pepper", 0.5, 4.5, True)]),
    ("gmsmith1918", 676371, "Ketchup squeezed from a bottle", [("squeeze", 1, 4.8, True)]),
    ("nataliegonzalez19", 636150, "Oil poured onto a pan", [("pour_oil", 1, 4.5, True)]),
    ("clement.bernardeau", 699231, "Oil poured into a bottle", [("pour_oil", 8, 6, True)]),
    ("FOSSarts", 740116, "Hot water poured into a ceramic cup", [("pour", 1, 4, True), ("drain", 2, 1.2, False)]),
    ("coltures", 391478, "Wooden spatula moving inside frying pan", [("stir_wood", 3, 0.7, False), ("stir_wood", 12, 0.7, False), ("stir_wood", 23, 0.7, False)]),
    ("spawklz", 166338, "Metal spatula and knife sliding on kitchen metal", [("stir_metal", 8, 0.65, False), ("stir_metal", 18, 0.65, False)]),
    ("OlyveBone", 486999, "Water stirred in a pot", [("stir_water", 5, 0.8, False), ("stir_water", 20, 0.8, False)]),
    ("fordps3", 336697, "Wet mixture stirred with wooden spoon", [("stir_wet", 4, 0.6, False), ("stir_wet", 12, 0.6, False)]),
    ("juanforeromusic", 464005, "Small quantity of rice poured into bowl", [("stir_dry", 1, 0.6, False), ("stir_dry", 3, 0.6, False)]),
    ("FOSSarts", 740092, "Gas stove igniting then burning", [("ignite", 0, 2.4, False), ("flame", 4.5, 2.6, True)]),
    ("Anthousai", 406066, "Tap water running into kitchen sink", [("water", 1, 8, True)]),
    ("BenParamoreAudio", 839155, "Quick potato chop with Santoku knife", [("chop", 0, 0, False)]),
    ("BenParamoreAudio", 839149, "Quick potato chop with Santoku knife", [("chop", 0, 0, False)]),
    ("BenParamoreAudio", 839145, "Quick potato chop with Santoku knife", [("chop", 0, 0, False)]),
    ("BenParamoreAudio", 839163, "Soft potato slice with Santoku knife", [("chop_soft", 0, 0, False)]),
    ("BenParamoreAudio", 839123, "Hard potato chop with Santoku knife", [("chop_hard", 0, 0, False)]),
    ("AlaskaRobotics", 221515, "Single metal service-bell ring", [("bell", 0, 0, False)]),
    ("OwlStorm", 209002, "Pots and pans clatter", [("pan", 0, 0, False)]),
    ("CapsLok", 181260, "Plate set down on hard kitchen surface", [("serve", 0, 0, False)]),
    ("milpower", 353105, "Glass bottle placed on glass plate", [("tap", 0, 0, False)]),
    ("OwlStorm", 151220, "Book page turn", [("paper", 0, 0, False)]),
    ("OwlStorm", 151221, "Book page turn variant", [("paper", 0, 0, False)]),
    ("mitchanary", 505171, "Cloth wiping a window", [("wipe", 2, 0.7, False), ("wipe", 7, 0.7, False)]),
    ("jopimblett", 388744, "Grapes dropped into a bowl", [("drop", 0, 0, False)]),
    ("KaleidacousticsAudio", 627655, "Pasta stirred in sauce in a saucepan", [("stir_pasta", 5, 0.8, False), ("stir_pasta", 15, 0.8, False)]),
    ("KaleidacousticsAudio", 627656, "Dry pasta dropped in ceramic bowl", [("drop_dry", 4, 0.8, False)]),
    ("SpliceSound", 218339, "Metal pot rattling while moved on stove", [("toss", 3.8, 1.3, False), ("toss", 7.3, 1.3, False)]),
    ("postworkflow", 360648, "Vegetables dropped into hot oil on stovetop", [("hot_drop", 11.7, 1.8, False)]),
    ("bowlingballout", 210100, "Metal domed pot lid lifted and placed down", [("lid_tick", 10.23, 0.3, False), ("lid_pop", 1.43, 0.55, False), ("lid_land", 12.62, 0.61, False)]),
    ("greenlinker", 757514, "Closing a pot lid", [("lid_close", 0.4, 0.65, False)]),
    ("wubitog", 234782, "Recorded air pressure release hiss, used as a steam-release approximation", [("steam_release", 0.19, 1.284, False)]),
]


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (compatible; RestaurantAudioLicenseAudit/1.0)"})
    with urllib.request.urlopen(request, timeout=45) as response:
        return response.read()


def fetch(entry, cache):
    author, sound_id, description, clips = entry
    url = f"https://freesound.org/people/{author}/sounds/{sound_id}/"
    page_file = cache / f"{sound_id}.html"
    if not page_file.exists():
        page_file.write_bytes(get(url))
    page = page_file.read_text(encoding="utf-8")
    if not re.search(r'href=[\"\']https?://creativecommons.org/publicdomain/zero/1.0/?[\"\']', page):
        raise ValueError(f"No verified CC0 license: {url}")
    preview = re.search(r'data-ogg="([^"]+)"', page)
    if not preview:
        raise ValueError(f"No public Ogg preview: {url}")
    media_url = html.unescape(preview.group(1))
    raw = cache / f"{sound_id}.ogg"
    if not raw.exists():
        raw.write_bytes(get(media_url))
    data, rate = sf.read(raw, always_2d=True, dtype="float32")
    print(f"CC0 {sound_id} {len(data)/rate:.2f}s {author}", flush=True)
    return entry, data.mean(axis=1), rate, {
        "id": sound_id, "author": author, "description": description,
        "page": url, "license": "CC0-1.0", "license_url": LICENSE,
        "license_checked": datetime.now(ZoneInfo("Asia/Shanghai")).date().isoformat(), "attribution_required": False,
        "download_url": media_url, "download_kind": "public lossy Ogg preview, not original lossless recording",
        "source_sha256": hashlib.sha256(raw.read_bytes()).hexdigest(),
        "page_sha256": hashlib.sha256(page.encode()).hexdigest(),
        "source_duration_seconds": round(len(data)/rate, 3), "source_sample_rate": rate,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--append-only", action="store_true", help="Process only source ids absent from the existing audited manifest")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    DEST.mkdir(parents=True, exist_ok=True)
    manifest_path = DEST / "manifest.json"
    bank_path = PROJECT / "modules/restaurant/data/audio_bank.json"
    previous = json.loads(manifest_path.read_text()) if args.append_only else {}
    bank = json.loads(bank_path.read_text()) if args.append_only else {}
    sources = list(previous.get("sources", []))
    outputs = list(previous.get("clips", []))
    known_ids = {int(row["id"]) for row in sources}
    entries = [entry for entry in SOURCES if entry[1] not in known_ids]
    with ThreadPoolExecutor(max_workers=3) as pool:
        recordings = list(pool.map(lambda entry: fetch(entry, args.cache), entries))
    for entry, data, rate, provenance in recordings:
        sources.append(provenance)
        for group, start, duration, loop in entry[3]:
            end = min(len(data), round((start + duration) * rate)) if duration else len(data)
            clip = data[round(start * rate):end].copy()
            if len(clip) < rate * 0.1 or np.max(np.abs(clip)) < 0.0001:
                raise ValueError(f"Empty/silent clip: {entry[1]} {group}")
            clip -= clip.mean()
            # Gain matching only: retain the recorded waveform and dynamics.
            rms = float(np.sqrt(np.mean(clip**2)))
            gain = min(0.12/max(rms, 1e-8), 0.63/float(np.max(np.abs(clip))), 8.0)
            clip *= gain
            if loop:
                blend = min(int(rate * .12), len(clip)//8)
                ramp = np.linspace(0, 1, blend)
                join = clip[-blend:] * (1-ramp) + clip[:blend] * ramp
                clip = np.concatenate((clip[blend:-blend], join))
            else:
                fade = min(int(rate*.008), len(clip)//4)
                clip[:fade] *= np.linspace(0, 1, fade)
                clip[-fade:] *= np.linspace(1, 0, fade)
            index = len(bank.get(group, [])) + 1
            name = f"{group}_{index:02d}.wav"
            target = DEST / name
            sf.write(target, clip, rate, subtype="PCM_16")
            resource = "res://modules/restaurant/assets/audio/recorded/" + name
            bank.setdefault(group, []).append(resource)
            outputs.append({"file": resource, "source_id": entry[1], "source_start_seconds": start,
                            "source_end_seconds": end/rate, "gain": round(gain, 6), "loop": loop,
                            "frames": len(clip), "sample_rate": rate, "channels": 1,
                            "peak": round(float(np.max(np.abs(clip))), 6),
                            "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    manifest = {"schema": 1, "license": "CC0-1.0", "processing": "Mono mix, DC removal, conservative gain, 8ms one-shot fades / 120ms loop crossfade. No synthesis, no generated noise.",
                "audition_status": "Not yet individually approved by human listening; event, decode, peak and integration checks are separate.",
                "sources": sources, "clips": outputs}
    (DEST / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
    (PROJECT / "modules/restaurant/data/audio_bank.json").write_text(json.dumps(bank, indent=2)+"\n", encoding="utf-8")
    print(f"Imported {len(outputs)} clips from {len(sources)} CC0 recordings in {len(bank)} banks")


if __name__ == "__main__":
    main()
