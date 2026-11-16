#!/usr/bin/env python3
"""Drive the NestKeep app on a CI emulator and capture real store screenshots.

Runs on the GitHub Actions runner after the emulator has booted (invoked
from the android-emulator-runner step). Installs the debug APK, walks the
first-run onboarding with its pre-filled defaults, taps "Build my plan",
then captures each bottom-nav screen at 1080x2160 (2:1, Play-safe).

Usage: python3 tools/screenshot_run.py <path-to-apk>
Output: screenshots/*.png in the repo root working directory.
"""
import os
import re
import subprocess
import sys
import time

PKG = "com.respawned.nestkeep"
OUT = os.path.abspath("screenshots")
os.makedirs(OUT, exist_ok=True)


def run(*args, binary=False):
    return subprocess.run(args, capture_output=True, text=not binary)


def adb(*args, binary=False):
    return run("adb", *args, binary=binary)


def dump():
    adb("shell", "uiautomator", "dump", "/sdcard/window_dump.xml")
    r = adb("exec-out", "cat", "/sdcard/window_dump.xml")
    return r.stdout or ""


def find(xml, text, min_y=0):
    """Center point of the first node whose text/content-desc contains text."""
    pat = re.compile(
        r'(?:text|content-desc)="([^"]*)"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
    )
    for m in pat.finditer(xml):
        label, x1, y1, x2, y2 = m.group(1), *map(int, m.groups()[1:])
        if text.lower() in label.lower() and y1 >= min_y:
            return ((x1 + x2) // 2, (y1 + y2) // 2)
    return None


def tap_text(text, timeout=30, required=True, min_y=0):
    end = time.time() + timeout
    while time.time() < end:
        p = find(dump(), text, min_y=min_y)
        if p:
            adb("shell", "input", "tap", str(p[0]), str(p[1]))
            print(f"tapped '{text}' at {p}")
            return True
        time.sleep(2)
    if required:
        raise SystemExit(f"FAIL: UI text not found: {text}")
    print(f"optional text not found, skipping: {text}")
    return False


def swipe_up():
    adb("shell", "input", "swipe", "540", "1750", "540", "650", "350")
    time.sleep(1)


def shot(name):
    time.sleep(3)
    r = adb("exec-out", "screencap", "-p", binary=True)
    data = r.stdout or b""
    if len(data) < 10000:
        raise SystemExit(f"FAIL: screenshot {name} too small ({len(data)} bytes)")
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(data)
    print(f"saved {name} ({len(data)} bytes)")


def main():
    apk = sys.argv[1]
    print("waiting for device...")
    adb("wait-for-device")
    # Play phone screenshots must not exceed a 2:1 aspect ratio.
    adb("shell", "wm", "size", "1080x2160")
    adb("shell", "settings", "put", "global", "window_animation_scale", "0")
    adb("shell", "settings", "put", "global", "transition_animation_scale", "0")

    print("installing", apk)
    r = adb("install", "-r", apk)
    print(r.stdout, r.stderr)
    if "Success" not in (r.stdout or ""):
        raise SystemExit("FAIL: APK install did not report Success")

    print("launching app")
    r = adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    print(r.stdout, r.stderr)
    time.sleep(10)

    # Onboarding: one scrollable form, defaults pre-filled. Scroll to the
    # "Build my plan" button and tap it.
    for _ in range(4):
        if find(dump(), "Build my plan"):
            break
        swipe_up()
    tap_text("Build my plan", timeout=20)
    time.sleep(4)

    # Notification permission dialog (either answer is fine for screenshots).
    tap_text("Allow", timeout=8, required=False)
    time.sleep(3)

    # Bottom nav lives in the bottom ~15% of the 2160px-tall screen.
    nav_min_y = 1800
    if not find(dump(), "Today", min_y=nav_min_y):
        raise SystemExit("FAIL: main screen with bottom nav never appeared")

    shot("01-today.png")
    tap_text("Plan", min_y=nav_min_y)
    shot("02-plan.png")
    tap_text("Scan", min_y=nav_min_y)
    shot("03-scan.png")
    tap_text("My Home", min_y=nav_min_y)
    shot("04-my-home.png")
    tap_text("Profile", min_y=nav_min_y)
    shot("05-profile.png")
    tap_text("Today", min_y=nav_min_y)
    print("done:", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
