"""Does pubspec.yaml actually bundle every prop MascotService references?

Six new props (chef hat, badge, headband, pilot gear, bubble tea, pug's
eyes) worked in every offline check today -- they measure correctly, they
don't clip the camera -- and still didn't show up on device, because
pubspec.yaml's assets list only ever had `glasses.glb` on it. Flutter
doesn't bundle a file just because it exists on disk; MascotService and
pubspec.yaml are two separate places that both have to agree a prop
exists, and nothing enforced that. Mascot3DStage's own bone-attach code
swallows the resulting "asset not found" into a silent no-op (better than
crashing the podium over a missing prop), which is exactly why this
looked like "only the first prop ever wired up actually works" rather
than what it was.

    python check_pubspec_assets.py

Exits non-zero (and lists the gaps) if any asset MascotService.dart
references isn't covered by pubspec.yaml's assets list -- either a plain
entry for that exact path, or a directory entry that contains it.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PUBSPEC = os.path.join(ROOT, "pubspec.yaml")
SERVICE = os.path.join(ROOT, "lib", "services", "mascot_service.dart")


def declared_assets():
    with open(PUBSPEC, encoding="utf-8") as f:
        lines = f.readlines()
    in_assets = False
    entries = []
    for line in lines:
        stripped = line.strip()
        if stripped == "assets:":
            in_assets = True
            continue
        if in_assets:
            if stripped.startswith("- "):
                entries.append(stripped[2:].strip())
            elif line.strip() and not line.startswith((" ", "\t")):
                break  # dedented past the assets block into the next top-level key
    return entries


def referenced_assets():
    with open(SERVICE, encoding="utf-8") as f:
        src = f.read()
    return sorted(set(re.findall(r"'(assets/[^']+\.(?:glb|ktx|png))'", src)))


def covered(path, declared):
    if path in declared:
        return True
    return any(d.endswith("/") and path.startswith(d) for d in declared)


if __name__ == "__main__":
    declared = declared_assets()
    referenced = referenced_assets()
    missing = [a for a in referenced if not covered(a, declared)]
    print(f"{len(referenced)} asset(s) referenced in mascot_service.dart, "
          f"{len(declared)} pubspec.yaml entries under assets:")
    for a in referenced:
        print(f"  {'ok' if covered(a, declared) else 'MISSING':7s} {a}")
    if missing:
        print(f"\n{len(missing)} asset(s) referenced but not covered by pubspec.yaml -- "
              f"add them or a directory entry that contains them.")
        sys.exit(1)
    print("\nCLEAN")
