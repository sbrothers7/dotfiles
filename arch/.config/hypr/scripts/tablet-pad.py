#!/usr/bin/env python3
"""Map the Wacom Intuos Pro pad (buttons + 2 dials) and the pen's top button to keys/scrolls,
per focused app. Config: tablet-pad.json next to this file, re-read when it changes.

The pad is grabbed (apps never see it); the pen is only read, so it keeps drawing normally and
its top button (BTN_STYLUS3, which GTK apps ignore) is used as a trigger. Pen strokes are also
watched for a scribble (fast zig-zag), which can trigger an action, e.g. undoing it and the stroke before.
Events come out of a uinput keyboard+wheel device, so they go to the focused window / pointer.
"""
import json
import math
import os
import re
import select
import socket
import subprocess
import sys
import time

import evdev
from evdev import ecodes as e

CONFIG = os.path.join(os.path.dirname(os.path.realpath(__file__)), "tablet-pad.json")
VENDOR = 0x056A

# evdev codes from this tablet (PTK670), see libwacom's wacom-intuos-pro-3-m.tablet
PAD_BUTTONS = {
    e.BTN_0: "l_top", e.BTN_1: "l_right", e.BTN_2: "l_bottom", e.BTN_3: "l_left", e.BTN_8: "l_center",
    e.BTN_4: "r_top", e.BTN_5: "r_right", e.BTN_6: "r_bottom", e.BTN_7: "r_left", e.BTN_9: "r_center",
}
PEN_BUTTONS = {e.BTN_STYLUS3: "pen_top", e.BTN_STYLUS2: "pen_middle", e.BTN_STYLUS: "pen_bottom"}
# dial -> (axis, sign of a clockwise step)
DIALS = {e.REL_WHEEL: ("left", -1), e.REL_HWHEEL: ("right", 1)}

KEY_GAP = 0.012  # seconds
FAST_GAP = 0.08  # dial detents closer together than this use a mode's "cw_fast"/"ccw_fast"

ALIASES = {"ctrl": "LEFTCTRL", "shift": "LEFTSHIFT", "alt": "LEFTALT", "super": "LEFTMETA"}


def keycodes(combo):
    """'ctrl+shift+z' -> [KEY_LEFTCTRL, KEY_LEFTSHIFT, KEY_Z]"""
    codes = []
    for part in filter(None, combo.lower().split("+")):
        name = "KEY_" + ALIASES.get(part, part).upper()
        if name not in e.ecodes:
            raise ValueError(f"unknown key {part!r} in {combo!r}")
        codes.append(e.ecodes[name])
    return codes


class Output:
    def __init__(self):
        keys = [c for n, c in e.ecodes.items() if n.startswith("KEY_") and c < 0x100]
        self.ui = evdev.UInput({
            e.EV_KEY: keys + [e.BTN_LEFT, e.BTN_RIGHT, e.BTN_MIDDLE],
            e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL, e.REL_WHEEL_HI_RES],
        }, name="tablet-pad virtual input")
        self.held = {}  # button name -> keycodes held by a "hold" action
        self.touchpad = Touchpad()

    def keys(self, codes, value):
        # one key per frame with a short gap: fcitx5 (which sees every key first) drops
        # presses/releases that arrive back to back
        for c in (codes if value else reversed(codes)):
            self.ui.write(e.EV_KEY, c, value)
            self.ui.syn()
            time.sleep(KEY_GAP)

    def tap(self, combo, times=1):
        print(f"tablet-pad: key {combo}" + (f" x{times}" if times > 1 else ""), file=sys.stderr, flush=True)
        *mods, key = keycodes(combo)
        self.keys(mods, 1)  # modifiers once, then the key `times` times
        for _ in range(times):
            self.keys([key], 1)
            self.keys([key], 0)
        self.keys(mods, 0)

    def scroll(self, mods, steps):
        print(f"tablet-pad: scroll {mods or '-'} {steps:+d}", file=sys.stderr, flush=True)
        codes = keycodes(mods)
        if codes:
            self.keys(codes, 1)
            time.sleep(KEY_GAP)
        for _ in range(abs(steps)):
            d = 1 if steps > 0 else -1
            self.ui.write(e.EV_REL, e.REL_WHEEL, d)
            self.ui.write(e.EV_REL, e.REL_WHEEL_HI_RES, 120 * d)
            self.ui.syn()
        if codes:
            time.sleep(KEY_GAP)
            self.keys(codes, 0)

    def pinch(self, factor):
        """Two-finger pinch on a virtual touchpad: apps get a zoom gesture of exactly `factor`
        (unlike wheel zoom, which GTK3 apps only get in whole notches / preset steps)."""
        print(f"tablet-pad: pinch x{factor:.4f}", file=sys.stderr, flush=True)
        self.touchpad.pinch(factor)

    def release_all(self):
        for codes in self.held.values():
            self.keys(codes, 0)
        self.held.clear()


class Touchpad:
    W, H, RES = 4000, 2800, 40  # units, units per mm
    KICK = 200  # first finger move: libinput needs ~5 mm to recognise the pinch, and measures scale from there

    def __init__(self):
        absinfo = lambda hi, res=0: evdev.AbsInfo(0, 0, hi, 0, 0, res)
        self.ui = evdev.UInput({
            e.EV_KEY: [e.BTN_LEFT, e.BTN_TOUCH, e.BTN_TOOL_FINGER, e.BTN_TOOL_DOUBLETAP],
            e.EV_ABS: [(e.ABS_X, absinfo(self.W, self.RES)), (e.ABS_Y, absinfo(self.H, self.RES)),
                       (e.ABS_MT_SLOT, absinfo(1)), (e.ABS_MT_TRACKING_ID, absinfo(65535)),
                       (e.ABS_MT_POSITION_X, absinfo(self.W, self.RES)),
                       (e.ABS_MT_POSITION_Y, absinfo(self.H, self.RES))],
        }, name="tablet-pad virtual touchpad", input_props=[e.INPUT_PROP_POINTER])
        self.tid = 0

    def fingers(self, d, down=False):
        cx, cy = self.W / 2, self.H / 2
        for slot, x in enumerate((cx - d / 2, cx + d / 2)):
            self.ui.write(e.EV_ABS, e.ABS_MT_SLOT, slot)
            if down:
                self.ui.write(e.EV_ABS, e.ABS_MT_TRACKING_ID, self.tid + slot)
            self.ui.write(e.EV_ABS, e.ABS_MT_POSITION_X, round(x))
            self.ui.write(e.EV_ABS, e.ABS_MT_POSITION_Y, round(cy))
        if down:
            self.ui.write(e.EV_KEY, e.BTN_TOUCH, 1)
            self.ui.write(e.EV_KEY, e.BTN_TOOL_DOUBLETAP, 1)
        self.ui.write(e.EV_ABS, e.ABS_X, round(cx - d / 2))
        self.ui.write(e.EV_ABS, e.ABS_Y, round(cy))
        self.ui.syn()
        time.sleep(0.004)

    def pinch(self, factor, d0=1600, steps=2):
        self.fingers(d0, down=True)
        d1 = d0 + (self.KICK if factor >= 1 else -self.KICK)
        self.fingers(d1)
        for i in range(1, steps + 1):
            self.fingers(d1 * factor ** (i / steps))
        for slot in (0, 1):
            self.ui.write(e.EV_ABS, e.ABS_MT_SLOT, slot)
            self.ui.write(e.EV_ABS, e.ABS_MT_TRACKING_ID, -1)
        self.ui.write(e.EV_KEY, e.BTN_TOUCH, 0)
        self.ui.write(e.EV_KEY, e.BTN_TOOL_DOUBLETAP, 0)
        self.ui.syn()
        self.tid = (self.tid + 2) % 65536


class Stroke:
    """Collects one pen-tip stroke and tells whether it was a scribble: a fast back-and-forth
    zig-zag along one direction (like scratching something out)."""
    MIN_REVERSALS = 4      # sharp turns back, i.e. at least 5 legs
    STEP_MM = 0.5          # path resampling
    CUSP_MM = 1.5          # how far before/after a point the turn-back is measured
    LEG_MM = (3, 60)       # median leg length
    MAX_LEG_S = 0.35       # median time per leg: slower zig-zags are drawing (hatching), not scribbling

    def __init__(self, pen):
        self.res = pen.absinfo(e.ABS_X).resolution or 200  # units per mm
        self.x = self.y = 0
        self.down = False
        self.rubber = False
        self.points = []

    def event(self, ev):
        """Feed a pen event; returns the finished stroke's points when the tip lifts."""
        if ev.type == e.EV_ABS and ev.code == e.ABS_X:
            self.x = ev.value
        elif ev.type == e.EV_ABS and ev.code == e.ABS_Y:
            self.y = ev.value
        elif ev.type == e.EV_KEY and ev.code == e.BTN_TOOL_RUBBER:
            self.rubber = bool(ev.value)
        elif ev.type == e.EV_KEY and ev.code == e.BTN_TOUCH:
            self.down = bool(ev.value) and not self.rubber
            if not ev.value:
                points, self.points = self.points, []
                return points
        elif ev.type == e.EV_SYN and ev.code == e.SYN_REPORT and self.down:
            self.points.append((ev.timestamp(), self.x, self.y))
        return None

    def is_scribble(self, points):
        # resample every STEP_MM along the path, so speed and jitter don't matter
        step = self.STEP_MM * self.res
        path = [points[0]]
        for t, x, y in points[1:]:
            d = math.hypot(x - path[-1][1], y - path[-1][2])
            while d >= step:
                pt, px, py = path[-1]
                f = step / d
                path.append((pt + (t - pt) * f, px + (x - px) * f, py + (y - py) * f))
                d -= step
        # cusps: the pen comes back the way it went (incoming and outgoing directions over
        # CUSP_MM differ by more than ~135 deg); smooth loops and curves have none
        k = max(1, round(self.CUSP_MM / self.STEP_MM))
        cusps = []
        for i in range(k, len(path) - k):
            (_, ax, ay), (_, bx, by), (_, cx, cy) = path[i - k], path[i], path[i + k]
            u, v = (bx - ax, by - ay), (cx - bx, cy - by)
            cos = (u[0] * v[0] + u[1] * v[1]) / (math.hypot(*u) * math.hypot(*v) or 1)
            if cos < -0.7:
                if cusps and i - cusps[-1][0] <= k:  # same cusp: keep the sharpest point
                    if cos < cusps[-1][1]:
                        cusps[-1] = (i, cos)
                else:
                    cusps.append((i, cos))
        if len(cusps) < self.MIN_REVERSALS:
            return False
        ends = [0] + [i for i, _ in cusps] + [len(path) - 1]
        legs = [((b - a) * self.STEP_MM, path[b][0] - path[a][0]) for a, b in zip(ends, ends[1:])]
        length = sorted(g[0] for g in legs)[len(legs) // 2]
        secs = sorted(g[1] for g in legs)[len(legs) // 2]
        return self.LEG_MM[0] <= length <= self.LEG_MM[1] and secs <= self.MAX_LEG_S

def osd(text):
    subprocess.Popen(["swayosd-client", "--custom-message", text, "--custom-icon", "input-tablet"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class Mapper:
    def __init__(self, out):
        self.out = out
        self.mtime = None
        self.profiles = []
        self.wclass = ""
        self.modes = {}    # (profile index, dial) -> mode index
        self.toggles = {}  # (profile index, button) -> next index
        self.last_turn = {}  # dial -> time of its previous detent
        self.tool = {}  # profile index -> last key a toggle sent (e.g. which GIMP tool is active)

    def reload(self):
        try:
            mtime = os.stat(CONFIG).st_mtime
            if mtime == self.mtime:
                return
            with open(CONFIG) as f:
                profiles = json.load(f)["profiles"]
            for p in profiles:  # fail on bad key names now, not mid-stroke
                for a in list(p.get("buttons", {}).values()) + [
                        x for modes in p.get("dials", {}).values() for m in modes
                        for x in (m.get("cw"), m.get("ccw"), m.get("cw_fast"), m.get("ccw_fast")) if x] + [
                        x for x in [p.get("scribble")] if x]:
                    for k in ("key", "hold"):
                        if k in a:
                            keycodes(a[k])
                    for k in a.get("toggle", []):
                        keycodes(k)
            self.profiles, self.mtime = profiles, mtime
            self.modes.clear()
            self.toggles.clear()
            self.tool.clear()
        except (OSError, ValueError, KeyError) as err:
            print(f"tablet-pad: config: {err}", file=sys.stderr)
            self.mtime = os.stat(CONFIG).st_mtime if os.path.exists(CONFIG) else None

    def profile(self):
        self.reload()
        for i, p in enumerate(self.profiles):
            if p["class"] == "default" or re.search(p["class"], self.wclass):
                return i, p
        return -1, {}

    def run(self, action, name, pressed):
        if not action:
            return
        if "hold" in action:
            if pressed:
                codes = keycodes(action["hold"])
                self.out.held[name] = codes
                self.out.keys(codes, 1)
            elif name in self.out.held:
                self.out.keys(self.out.held.pop(name), 0)
            return
        if not pressed:
            return
        idx, _ = self.profile()
        if "key" in action:
            self.out.tap(action["key"], action.get("times", 1))
        elif "toggle" in action:
            n = self.toggles.get((idx, name), 0)
            self.out.tap(action["toggle"][n])
            self.tool[idx] = action["toggle"][n]
            names = action.get("names")
            if names:
                osd(names[n])
            self.toggles[(idx, name)] = (n + 1) % len(action["toggle"])
        elif "mode" in action:
            dial = action["mode"]
            modes = self.profile()[1].get("dials", {}).get(dial, [])
            if modes:
                m = (self.modes.get((idx, dial), 0) + 1) % len(modes)
                self.modes[(idx, dial)] = m
                osd(f"{dial.capitalize()} dial: {modes[m].get('name', m + 1)}")

    def button(self, name, pressed):
        if not pressed and name in self.out.held:  # release even if the profile changed meanwhile
            self.out.keys(self.out.held.pop(name), 0)
            return
        self.run(self.profile()[1].get("buttons", {}).get(name), name, pressed)

    def dial(self, dial, steps):
        idx, p = self.profile()
        modes = p.get("dials", {}).get(dial, [])
        if not modes:
            return
        mode = modes[self.modes.get((idx, dial), 0) % len(modes)]
        now = time.monotonic()
        fast = abs(steps) > 1 or now - self.last_turn.get(dial, 0) < FAST_GAP
        self.last_turn[dial] = now
        if "scroll" in mode:
            self.out.scroll(mode["scroll"], steps)
            return
        if "pinch" in mode:
            self.out.pinch(mode["pinch"] ** steps)
            return
        name = "cw" if steps > 0 else "ccw"
        action = mode.get(name + "_fast" if fast else name) or mode.get(name)
        if action and "key" in action:
            self.out.tap(action["key"], abs(steps))
            return
        for _ in range(abs(steps)):
            self.run(action, dial, True)

    def stroke(self, stroke, points):
        idx, p = self.profile()
        action = p.get("scribble")
        if not action or not points:
            return
        tools = action.get("tools")
        if tools and self.tool.get(idx, tools[0]) not in tools:  # e.g. erasing: scribbles are wanted
            return
        if stroke.is_scribble(points):
            print("tablet-pad: scribble", file=sys.stderr, flush=True)
            time.sleep(0.05)  # let the app finish the stroke first
            self.run(action, "scribble", True)

    def focus(self, wclass):
        if wclass != self.wclass:
            self.out.release_all()
            self.wclass = wclass


def find(suffix):
    for path in evdev.list_devices():
        d = evdev.InputDevice(path)
        if d.info.vendor == VENDOR and d.name.endswith(suffix):
            return d
        d.close()
    return None


def hypr_socket():
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], "hypr",
                              os.environ["HYPRLAND_INSTANCE_SIGNATURE"], ".socket2.sock"))
    return sock


def active_class():
    try:
        out = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True).stdout
        return json.loads(out).get("class", "")
    except (OSError, ValueError):
        return ""


def main():
    out = Output()
    mapper = Mapper(out)
    mapper.focus(active_class())
    hypr = hypr_socket()
    buf = b""
    while True:
        pad, pen = find(" Pad"), find(" Pen")
        if not pad:
            # tablet unplugged: keep following focus, look again in a bit
            r, _, _ = select.select([hypr], [], [], 2)
        else:
            pad.grab()
            print(f"tablet-pad: using {pad.path} {pen.path if pen else '(no pen)'}", file=sys.stderr)
            devs = {pad.fd: pad}
            if pen:
                devs[pen.fd] = pen
                stroke = Stroke(pen)
            try:
                while True:
                    r, _, _ = select.select([hypr, *devs], [], [])
                    # detents that queued up while the last action ran are merged into one
                    # action (one pinch / scroll), so a fast spin doesn't leave a backlog
                    turns = {}
                    for fd in r:
                        if fd is hypr:
                            continue
                        for ev in devs[fd].read():
                            if devs[fd] is pen:
                                points = stroke.event(ev)
                                if points is not None:
                                    mapper.stroke(stroke, points)
                            if ev.type == e.EV_KEY and ev.value in (0, 1):
                                name = (PAD_BUTTONS if devs[fd] is pad else PEN_BUTTONS).get(ev.code)
                                if name:
                                    for dial in list(turns):  # keep order: turns before the press
                                        mapper.dial(dial, turns.pop(dial))
                                    mapper.button(name, ev.value == 1)
                            elif ev.type == e.EV_REL and ev.code in DIALS and devs[fd] is pad:
                                dial, cw = DIALS[ev.code]
                                turns[dial] = turns.get(dial, 0) + ev.value * cw
                    for dial, steps in turns.items():
                        if steps:
                            mapper.dial(dial, steps)
                    if hypr in r:
                        buf = read_hypr(hypr, buf, mapper)
            except OSError:  # device gone
                out.release_all()
                for d in devs.values():
                    try:
                        d.close()
                    except OSError:
                        pass
                time.sleep(1)
                continue
        if hypr in r:
            buf = read_hypr(hypr, buf, mapper)


def read_hypr(sock, buf, mapper):
    data = sock.recv(65536)
    if not data:
        sys.exit("tablet-pad: Hyprland socket closed")
    buf += data
    *lines, buf = buf.split(b"\n")
    for line in lines:
        if line.startswith(b"activewindow>>"):
            mapper.focus(line[14:].decode(errors="replace").split(",", 1)[0])
    return buf


if __name__ == "__main__":
    main()
