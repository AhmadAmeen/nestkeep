#!/usr/bin/env python3
"""Drive the NestKeep app on a CI emulator and capture real store screenshots.

Runs on the GitHub Actions runner after the emulator has booted (invoked
from the android-emulator-runner step). Installs the debug APK, walks the
first-run onboarding with its pre-filled defaults, taps "Build my plan",
then captures each bottom-nav screen at 1080x2160 (2:1, Play-safe).

Diagnostics: every UI dump's visible texts are printed to the log, a launch
screenshot and the raw dump XML are saved into screenshots/ (uploaded even
on failure), and a filtered logcat tail is printed before any failure exit.

Usage: python3 tools/screenshot_run.py <path-to-apk>
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


def visible_texts(xml):
    texts = re.findall(r'(?:text|content-desc)="([^"]+)"', xml)
    seen, out = set(), []
    for t in texts:
        if t not in seen:
            seen.add(t)
            out.append(t)
    return out


NODE_RE = re.compile(r"<node[^>]*>")
BOUNDS_RE = re.compile(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')


def _attr(tag, name):
    m = re.search(name + r'="([^"]*)"', tag)
    return m.group(1) if m else ""


def find(xml, text, min_y=0):
    """Center point of the first node whose label contains text.

    Each <node> tag is parsed on its own: Flutter puts labels in
    content-desc with text="" empty, and a single regex spanning both
    attributes matches text="" first and swallows the node (the bug that
    sank the v1/v2 runs), so the attributes are read per-tag here.
    """
    for m in NODE_RE.finditer(xml):
        tag = m.group(0)
        label = _attr(tag, "content-desc") or _attr(tag, "text")
        if not label:
            continue
        b = BOUNDS_RE.search(tag)
        if not b:
            continue
        x1, y1, x2, y2 = map(int, b.groups())
        if text.lower() in label.lower() and y1 >= min_y:
            return ((x1 + x2) // 2, (y1 + y2) // 2)
    return None


def tap_text(text, timeout=30, required=True, min_y=0):
    end = time.time() + timeout
    while time.time() < end:
        p = find(dump(), text, min_y=min_y)
        if p:
            adb("shell", "input", "tap", str(p[0]), str(p[1]))
            print(f"tapped '{text}' at {p}", flush=True)
            return True
        time.sleep(2)
    if required:
        fail(f"UI text not found: {text}")
    print(f"optional text not found, skipping: {text}", flush=True)
    return False


def swipe_up():
    adb("shell", "input", "swipe", "540", "1750", "540", "650", "350")
    time.sleep(1)


def shot(name):
    time.sleep(3)
    r = adb("exec-out", "screencap", "-p", binary=True)
    data = r.stdout or b""
    if len(data) < 10000:
        fail(f"screenshot {name} too small ({len(data)} bytes)")
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(data)
    print(f"saved {name} ({len(data)} bytes)", flush=True)


def fail(msg):
    print(f"FAIL: {msg}", flush=True)
    try:
        xml = dump()
        with open(os.path.join(OUT, "diag-dump.xml"), "w") as f:
            f.write(xml)
        print("visible texts at failure:", visible_texts(xml)[:40], flush=True)
        r = adb("exec-out", "screencap", "-p", binary=True)
        if r.stdout and len(r.stdout) > 1000:
            with open(os.path.join(OUT, "diag-screen.png"), "wb") as f:
                f.write(r.stdout)
        lc = adb("logcat", "-d", "-t", "400")
        lines = (lc.stdout or "").splitlines()
        interesting = [
            ln for ln in lines
            if any(k in ln for k in ("FATAL", "AndroidRuntime", "flutter",
                                     "NestKeep", "nestkeep", "Exception"))
        ]
        print("--- logcat tail (filtered) ---", flush=True)
        for ln in interesting[-60:]:
            print(ln, flush=True)
    except Exception as e:  # diagnostics must never mask the real failure
        print("diagnostics failed:", e, flush=True)
    sys.exit(1)


def wait_for_text(text, timeout=90):
    """Poll the UI dump until text appears; print what IS visible meanwhile."""
    end = time.time() + timeout
    while time.time() < end:
        xml = dump()
        if find(xml, text):
            print(f"found '{text}'", flush=True)
            return xml
        print("waiting; visible:", visible_texts(xml)[:25], flush=True)
        time.sleep(10)
    return None


def main():
    apk = sys.argv[1]
    print("waiting for device...", flush=True)
    adb("wait-for-device")
    # Play phone screenshots must not exceed a 2:1 aspect ratio.
    adb("shell", "wm", "size", "1080x2160")

    print("installing", apk, flush=True)
    r = adb("install", "-r", apk)
    print(r.stdout, r.stderr, flush=True)
    if "Success" not in (r.stdout or ""):
        fail("APK install did not report Success")

    print("launching app", flush=True)
    r = adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    print(r.stdout, r.stderr, flush=True)

    # Wait for the onboarding screen to render (spinner shows first).
    xml = wait_for_text("Welcome home", timeout=90)
    if xml is None:
        fail("onboarding 'Welcome home' never appeared")

    shot("00-onboarding.png")

    # The form is long; the button enters the semantics tree only when
    # scrolled into view. Scroll gradually until it shows up.
    for i in range(10):
        if find(dump(), "Build my plan"):
            break
        print(f"scroll {i + 1}: button not visible yet", flush=True)
        swipe_up()
    tap_text("Build my plan", timeout=20)
    time.sleep(4)

    # Notification permission dialog (either answer is fine for screenshots).
    tap_text("Allow", timeout=8, required=False)
    time.sleep(3)

    # Bottom nav lives in the bottom ~15% of the 2160px-tall screen.
    nav_min_y = 1800
    if not find(dump(), "Today", min_y=nav_min_y):
        fail("main screen with bottom nav never appeared")

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
    print("done:", sorted(os.listdir(OUT)), flush=True)


if __name__ == "__main__":
    main()
