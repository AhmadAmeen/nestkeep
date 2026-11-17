#!/usr/bin/env python3
"""Drive the NestKeep app on a CI emulator and capture real store screenshots.

Runs on the GitHub Actions runner after the emulator has booted (invoked
from the android-emulator-runner step). Installs the release APK (no
debug banner in store shots), skips the intro slides, steps through the
onboarding wizard with its pre-filled defaults, taps "Build my plan",
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
    """UI hierarchy XML. uiautomator intermittently returns only the bare
    native shell (no Flutter semantics nodes at all) when it queries
    mid-frame; if the result has no labelled nodes, wait and dump again."""
    xml = ""
    for _ in range(3):
        adb("shell", "uiautomator", "dump", "/sdcard/window_dump.xml")
        r = adb("exec-out", "cat", "/sdcard/window_dump.xml")
        xml = r.stdout or ""
        if 'content-desc="' in xml and len(xml) > 3000:
            break
        time.sleep(2)
    return xml


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


def find(xml, text, min_y=0, exact=False):
    """Center point of the best node whose label contains text.

    Each <node> tag is parsed on its own: Flutter puts labels in
    content-desc with text="" empty, and a single regex spanning both
    attributes matches text="" first and swallows the node (the bug that
    sank the v1/v2 runs), so the attributes are read per-tag here.

    Among matches, the SHORTEST label wins: the notification dialog title
    "Allow NestKeep to send you notifications?" contains "Allow" and sits
    earlier in the tree than the Allow button, so first-match tapped the
    title and the dialog stayed up (the v3 run's failure). With exact=True
    only a node whose whole label equals text matches.
    """
    best = None  # (label_length, cx, cy)
    for m in NODE_RE.finditer(xml):
        tag = m.group(0)
        label = _attr(tag, "content-desc") or _attr(tag, "text")
        if not label:
            continue
        if exact:
            if label.strip() != text:
                continue
        elif text.lower() not in label.lower():
            continue
        b = BOUNDS_RE.search(tag)
        if not b:
            continue
        x1, y1, x2, y2 = map(int, b.groups())
        if y1 < min_y:
            continue
        cand = (len(label), (x1 + x2) // 2, (y1 + y2) // 2)
        if best is None or cand[0] < best[0]:
            best = cand
    return (best[1], best[2]) if best else None


def tap_text(text, timeout=30, required=True, min_y=0, exact=False):
    end = time.time() + timeout
    while time.time() < end:
        p = find(dump(), text, min_y=min_y, exact=exact)
        if p:
            adb("shell", "input", "tap", str(p[0]), str(p[1]))
            print(f"tapped '{text}' at {p}", flush=True)
            return True
        time.sleep(2)
    if required:
        fail(f"UI text not found: {text}")
    print(f"optional text not found, skipping: {text}", flush=True)
    return False


def shot(name):
    time.sleep(3)
    # Warm-up capture, discarded: under the software renderer the first
    # screencap after a screen change can grab a cleared buffer (white
    # body, nav painted) even though the widget tree is fully built
    # (run #13: Today and Scan blank, Plan/My Home/Profile fine, all
    # static synchronous layouts). The throwaway grab forces a fresh
    # composite so the saved capture is the painted frame.
    adb("exec-out", "screencap", "-p", binary=True)
    time.sleep(1)
    r = adb("exec-out", "screencap", "-p", binary=True)
    data = r.stdout or b""
    if len(data) < 10000:
        fail(f"screenshot {name} too small ({len(data)} bytes)")
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(data)
    print(f"saved {name} ({len(data)} bytes)", flush=True)


def wait_content(text, timeout=40):
    """Advisory wait: poll the dump until a tab's content label shows.
    Never fails the run (the tree itself is intermittently bare on this
    emulator); it just gives slow first frames time to land before the
    capture."""
    end = time.time() + timeout
    while time.time() < end:
        if find(dump(), text):
            print(f"content ready: '{text}'", flush=True)
            time.sleep(2)
            return True
        time.sleep(3)
    print(f"content label never seen (continuing): '{text}'", flush=True)
    return False


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


def wait_for_any(texts, timeout=90):
    """Like wait_for_text, but the first of several labels wins. Returns
    (xml, matched_text) or (None, None)."""
    end = time.time() + timeout
    while time.time() < end:
        xml = dump()
        for t in texts:
            if find(xml, t):
                print(f"found '{t}'", flush=True)
                return xml, t
        print("waiting; visible:", visible_texts(xml)[:25], flush=True)
        time.sleep(10)
    return None, None


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

    # First paint is the splash, then either the intro slides (new
    # builds) or onboarding step 1 directly (older builds).
    xml, hit = wait_for_any(["Your home, handled", "Welcome home"],
                            timeout=90)
    if xml is None:
        fail("neither intro nor onboarding appeared after launch")
    if hit == "Your home, handled":
        # Skip the intro; onboarding follows immediately.
        tap_text("Skip", timeout=20, exact=True)
        xml = wait_for_text("Welcome home", timeout=60)
        if xml is None:
            fail("onboarding 'Welcome home' never appeared after intro")

    shot("00-onboarding.png")

    # Onboarding is a step wizard: tap Next through the steps (defaults
    # are pre-filled, Next is always enabled) until the summary step's
    # build button enters the tree, then tap it.
    for i in range(6):
        if find(dump(), "Build my plan"):
            break
        print(f"wizard: tapping Next ({i + 1})", flush=True)
        tap_text("Next", timeout=20, exact=True)
        time.sleep(2)
    tap_text("Build my plan", timeout=20)
    time.sleep(4)

    # Notification permission dialog (either answer is fine for screenshots).
    tap_text("Allow", timeout=8, required=False, exact=True)
    time.sleep(3)

    # After onboarding, this emulator's software renderer leaves the main
    # screen's accessibility tree empty and its frames unreliable (runs
    # #11/#12: nav painted, body blank, every dump a bare shell, plus
    # "bad color buffer handle" gralloc errors). Do not depend on the UI
    # tree from here: restart the app cold (the home now exists, so it
    # opens straight into the main screen) and drive the bottom nav by
    # fixed coordinates. Dumps are advisory prints only from this point.
    adb("shell", "am", "force-stop", PKG)
    time.sleep(2)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(8)
    # Today is the first frame after the cold start and the one this
    # renderer most often hands back blank; wait for its content label
    # before shooting (run #13's Today was a white body over the nav).
    wait_content("Welcome home", timeout=60)
    print("after relaunch; visible:", visible_texts(dump())[:25], flush=True)

    shot("01-today.png")
    # Bottom nav: 5 equal tabs across 1080px, centred around y=2040.
    # Each tab gets its own content wait: run #13's Scan came back blank
    # the same way, while tabs whose frames had settled painted fine.
    for name, x, label in (
        ("02-plan.png", 324, "Your plan"),
        ("03-scan.png", 540, "Scan a receipt"),
        ("04-my-home.png", 756, "Appliances"),
        ("05-profile.png", 972, "Guest mode"),
    ):
        adb("shell", "input", "tap", str(x), "2040")
        time.sleep(3)
        wait_content(label, timeout=30)
        print(f"tapped nav x={x}; visible:", visible_texts(dump())[:15],
              flush=True)
        shot(name)
    print("done:", sorted(os.listdir(OUT)), flush=True)


if __name__ == "__main__":
    main()
