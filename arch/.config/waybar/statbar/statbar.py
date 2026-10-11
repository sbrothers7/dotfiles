#!/usr/bin/env python3
"""statbar: the right-hand stat modules of the bar, with interactive hover panels.

Waybar tooltips can't be hovered, clicked or point-inspected, so these modules live in
their own layer-shell strip drawn over waybar's (empty) right side. Hovering a module
opens a panel that stays open while the pointer is on it; graphs show the exact value
under the pointer.
"""
import fcntl
import json
import math
import os
import sys
import threading
import time

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
gi.require_version("PangoCairo", "1.0")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell, Pango, PangoCairo  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sources import HISTORY, Sampler, fmt_axis, fmt_rate, fmt_size, nice_ceiling  # noqa: E402
from workspaces import Workspaces  # noqa: E402

CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")
DEFAULTS = {
    "stat_interval": 1.0,    # seconds between samples: bar text, panel "now" values, per-core bars
    "graph_interval": 2.0,   # seconds per graph point (average of the samples in that span)
    "graph_points": HISTORY,  # points kept per graph; span = graph_points * graph_interval
}
CFG = dict(DEFAULTS)     # live config; config.json is re-read whenever it changes
SHOW_DELAY = 150       # ms hovering a module before its panel opens
HIDE_DELAY = 250       # ms after the pointer leaves module + panel before it closes
BAR_TOP, BAR_HEIGHT, BAR_RIGHT = 8, 34, 10   # match waybar's margin-top / height / margin-right
BAR_LEFT = 12
PANEL_GAP = 6
GRAPH_W = 520
HOT = 85

FONT = "JetBrainsMono Nerd Font"
BLUE, RED = "#a1b7ce", "#cea1a1"   # the two-way distinctions (P/E, down/up, read/write, CPU/GPU)
TINT = {                            # per-module colors (bar labels + single-series graphs)
    "cpu": "#a1b6ce", "gpu": "#aacea1", "ram": "#b0a1ce",
    "tmp": "#ceb4a1", "net": "#a1cece", "dsk": "#cec6a1",
}
LABEL = "#c7d5e6"   # bar module labels (lighter CPU tint); TINT is for the panels only
DIM = "#8a8a8a"

HERE = os.path.dirname(os.path.abspath(__file__))
PREFS = os.path.expanduser("~/.cache/statbar.json")
LOCK = threading.RLock()   # sampler thread vs. GTK drawing of the same deques


def load_config():
    """Merge config.json over DEFAULTS; bad or missing values fall back to the defaults."""
    cfg = dict(DEFAULTS)
    try:
        with open(CONFIG) as f:
            user = json.load(f)
    except (OSError, ValueError):
        user = {}
    for k, default in DEFAULTS.items():
        try:
            v = float(user.get(k, default))
            cfg[k] = v if v > 0 else default
        except (TypeError, ValueError):
            pass
    cfg["stat_interval"] = max(0.1, cfg["stat_interval"])
    cfg["graph_interval"] = max(cfg["stat_interval"], cfg["graph_interval"])
    cfg["graph_points"] = max(2, int(cfg["graph_points"]))
    return cfg


def fmt_ago(seconds):
    if seconds < 60:
        return f"{seconds:g}s"
    if seconds < 3600:
        return f"{seconds / 60:g}m"
    return f"{seconds / 3600:g}h"


def rgb(hex_color, alpha=1.0):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (alpha,)


def esc(s):
    return GLib.markup_escape_text(str(s))


def span(s, color):
    return f"<span foreground='{color}'>{s}</span>"


def dim(s):
    return span(s, DIM)


def pct(v):
    return f"{v:.0f}%"


def deg(v):
    return "--" if v is None else f"{v:.0f}°"


def stats_markup(now, hist, fmt):
    """`now` is the live value; avg/min/max span the graph history."""
    if now is None:
        return dim("collecting…")
    vals = list(hist) or [now]
    return (dim("now ") + fmt(now) + dim("   avg ") + fmt(sum(vals) / len(vals)) +
            dim("   min ") + fmt(min(vals)) + dim("   max ") + fmt(max(vals)))


# ---------- cairo helpers ----------

def layout(cr, text, size=11, bold=False):
    lay = PangoCairo.create_layout(cr)
    lay.set_font_description(Pango.FontDescription.from_string(
        f"{FONT} {'Bold' if bold else ''} {size}px"))
    lay.set_text(text, -1)
    return lay


def draw_text(cr, text, x, y, color, size=11, bold=False, align="left"):
    lay = layout(cr, text, size, bold)
    w, h = lay.get_pixel_size()
    if align == "right":
        x -= w
    elif align == "center":
        x -= w / 2
    cr.set_source_rgba(*rgb(color))
    cr.move_to(x, y)
    PangoCairo.show_layout(cr, lay)
    return w, h


def rounded_rect(cr, x, y, w, h, r):
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cr.close_path()


def draw_tip(cr, lines, ax, ay, width, height):
    """Small value box near (ax, ay); lines = [(text, color)]."""
    lays = [(layout(cr, t, 11, True), c) for t, c in lines]
    sizes = [l.get_pixel_size() for l, _ in lays]
    bw = max(w for w, _ in sizes) + 14
    bh = sum(h for _, h in sizes) + 10
    x = ax + 12 if ax + 12 + bw <= width else ax - 12 - bw
    y = min(max(ay - bh / 2, 0), height - bh)
    rounded_rect(cr, x, y, bw, bh, 5)
    cr.set_source_rgba(0.08, 0.08, 0.08, 0.95)
    cr.fill_preserve()
    cr.set_source_rgba(1, 1, 1, 0.2)
    cr.set_line_width(1)
    cr.stroke()
    ty = y + 5
    for (lay, c), (_, h) in zip(lays, sizes):
        cr.set_source_rgba(*rgb(c))
        cr.move_to(x + 7, ty)
        PangoCairo.show_layout(cr, lay)
        ty += h


class Hoverable(Gtk.DrawingArea):
    """DrawingArea that tracks the pointer position."""

    def __init__(self, width, height):
        super().__init__()
        self.set_size_request(width, height)
        self.add_events(Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.ENTER_NOTIFY_MASK |
                        Gdk.EventMask.LEAVE_NOTIFY_MASK)
        self.hover = None
        self.connect("motion-notify-event", self._motion)
        self.connect("enter-notify-event", self._motion)
        self.connect("leave-notify-event", self._leave)
        self.connect("draw", self._draw)

    def _draw(self, w, cr):
        with LOCK:
            self.paint(cr, w.get_allocated_width(), w.get_allocated_height())

    def _motion(self, _w, ev):
        self.hover = (ev.x, ev.y)
        self.queue_draw()

    def _leave(self, _w, _ev):
        self.hover = None
        self.queue_draw()


AXIS_W, PAD_T, PAD_B = 44, 6, 18


class Graph(Hoverable):
    """History line graph. series: callable -> [(name, values, color)]."""

    def __init__(self, series, fmt, axis_fmt, top=None, bottom=0.0, height=110, ceil=nice_ceiling):
        super().__init__(GRAPH_W, height)
        self.series, self.fmt, self.axis_fmt = series, fmt, axis_fmt
        self.top, self.bottom, self.ceil = top, bottom, ceil

    def paint(self, cr, w, h):
        series = self.series()
        lo = self.bottom
        top = self.top if self.top is not None else self.ceil(
            max((max(v) for _, v, _ in series if v), default=0))
        pw, ph = w - AXIS_W - 4, h - PAD_T - PAD_B
        x0, y0 = AXIS_W, PAD_T
        points, gi = CFG["graph_points"], CFG["graph_interval"]
        step = pw / (points - 1)
        ymap = lambda v: y0 + ph * (1 - max(0.0, min(1.0, (v - lo) / (top - lo))))

        cr.set_line_width(1)
        for f in (0, 0.5, 1):
            y = round(y0 + ph * (1 - f)) + 0.5
            cr.set_source_rgba(1, 1, 1, 0.16 if f == 0 else 0.07)
            cr.move_to(x0, y)
            cr.line_to(x0 + pw, y)
            cr.stroke()
            draw_text(cr, self.axis_fmt(lo + (top - lo) * f), x0 - 6, y - 7, DIM, 10, align="right")
        draw_text(cr, f"-{fmt_ago(round(points * gi))}", x0, y0 + ph + 3, DIM, 10)
        draw_text(cr, "now", x0 + pw, y0 + ph + 3, DIM, 10, align="right")

        for _, vals, color in series:
            if len(vals) < 2:
                continue
            pts = [(x0 + pw - (len(vals) - 1 - i) * step, ymap(v)) for i, v in enumerate(vals)]
            cr.move_to(pts[0][0], ymap(lo))
            for x, y in pts:
                cr.line_to(x, y)
            cr.line_to(pts[-1][0], ymap(lo))
            cr.close_path()
            cr.set_source_rgba(*rgb(color, 0.16))
            cr.fill()
            cr.move_to(*pts[0])
            for x, y in pts[1:]:
                cr.line_to(x, y)
            cr.set_source_rgba(*rgb(color))
            cr.set_line_width(1.6)
            cr.stroke()

        if self.hover and series and x0 <= self.hover[0] <= x0 + pw + 4:
            back = round((x0 + pw - self.hover[0]) / step)
            n = max(len(v) for _, v, _ in series)
            if 0 <= back < n:
                x = x0 + pw - back * step
                cr.set_source_rgba(1, 1, 1, 0.35)
                cr.set_line_width(1)
                cr.move_to(round(x) + 0.5, y0)
                cr.line_to(round(x) + 0.5, y0 + ph)
                cr.stroke()
                lines = [("now" if back == 0 else f"{fmt_ago(round(back * gi, 1))} ago", "#e8e8e8")]
                for name, vals, color in series:
                    if back < len(vals):
                        v = vals[len(vals) - 1 - back]
                        cr.arc(x, ymap(v), 3.5, 0, 2 * math.pi)
                        cr.set_source_rgba(*rgb(color))
                        cr.fill()
                        lines.append((f"{name} {self.fmt(v)}" if name else self.fmt(v), color))
                draw_tip(cr, lines, x, self.hover[1], w, h)


class Bars(Hoverable):
    """Vertical bar chart. items: callable -> [(axis label, value, color, hover title)]."""

    def __init__(self, items, fmt, axis_fmt, top=100.0, bottom=0.0, height=100):
        super().__init__(GRAPH_W, height)
        self.items, self.fmt, self.axis_fmt, self.top, self.bottom = items, fmt, axis_fmt, top, bottom

    def paint(self, cr, w, h):
        items = self.items()
        if not items:
            return
        pw, ph = w - AXIS_W - 4, h - PAD_T - PAD_B
        x0, y0 = AXIS_W, PAD_T
        slot = pw / len(items)
        frac = lambda v: max(0.0, min(1.0, (v - self.bottom) / (self.top - self.bottom)))
        hovered = None
        if self.hover and x0 <= self.hover[0] < x0 + pw:
            hovered = int((self.hover[0] - x0) // slot)

        cr.set_line_width(1)
        for f in (0, 0.5, 1):
            y = round(y0 + ph * (1 - f)) + 0.5
            cr.set_source_rgba(1, 1, 1, 0.16 if f == 0 else 0.07)
            cr.move_to(x0, y)
            cr.line_to(x0 + pw, y)
            cr.stroke()
            draw_text(cr, self.axis_fmt(self.bottom + (self.top - self.bottom) * f), x0 - 6, y - 7, DIM, 10, align="right")

        bw = max(2.0, slot * 0.72)
        for i, (label, v, color, _) in enumerate(items):
            x = x0 + i * slot + (slot - bw) / 2
            bh = max(1.0, ph * frac(v))
            rounded_rect(cr, x, y0 + ph - bh, bw, bh, min(3, bw / 2, bh / 2))
            cr.set_source_rgba(*rgb(color, 1.0 if hovered in (None, i) else 0.45))
            cr.fill()
            draw_text(cr, label, x + bw / 2, y0 + ph + 3, "#e8e8e8" if hovered == i else DIM, 10, align="center")

        if hovered is not None and hovered < len(items):
            label, v, color, title = items[hovered]
            cx = x0 + hovered * slot + slot / 2
            draw_tip(cr, [(title, "#e8e8e8"), (self.fmt(v), color)], cx, self.hover[1], w, h)


class FsList(Hoverable):
    """Filesystem usage rows; hovering a row shows the exact numbers."""
    ROW = 24

    def __init__(self, rows, color, size):
        super().__init__(GRAPH_W, self.ROW)
        self.rows, self.color, self.size = rows, color, size

    def sync(self):
        height = self.ROW * max(1, len(self.rows()))
        if self.get_size_request()[1] != height:
            self.set_size_request(GRAPH_W, height)

    def paint(self, cr, w, h):
        rows = self.rows()
        name_w, text_w = 130, 200
        bar_x, bar_w = name_w, w - name_w - text_w - 8
        hovered = int(self.hover[1] // self.ROW) if self.hover else None
        for i, fs in enumerate(rows):
            y = i * self.ROW
            frac = fs["used"] / fs["total"] if fs["total"] else 0
            draw_text(cr, " ".join(fs["mounts"])[:16], 0, y + 4, "#e8e8e8", 12, True)
            rounded_rect(cr, bar_x, y + 7, bar_w, 10, 3)
            cr.set_source_rgba(1, 1, 1, 0.12)
            cr.fill()
            if frac > 0:
                rounded_rect(cr, bar_x, y + 7, max(6, bar_w * frac), 10, 3)
                cr.set_source_rgba(*rgb(self.color, 1.0 if hovered in (None, i) else 0.5))
                cr.fill()
            draw_text(cr, f"{self.size(fs['used'])} / {self.size(fs['total'])}  {frac * 100:3.0f}%",
                      w, y + 4, "#e8e8e8", 12, True, align="right")
        if hovered is not None and hovered < len(rows):
            fs = rows[hovered]
            draw_tip(cr, [(f"{fs['dev']} · free {self.size(fs['free'])}", self.color)],
                     self.hover[0], hovered * self.ROW + self.ROW / 2, w, h)


# ---------- panels ----------

def label(css_class=None):
    l = Gtk.Label(xalign=0)
    if css_class:
        l.get_style_context().add_class(css_class)
    return l


class Panel:
    """Content of one hover panel: a vertical box plus a refresh function."""

    def __init__(self):
        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.box.get_style_context().add_class("panel")
        self.updaters, self.drawables = [], []

    def text(self, fn, css_class=None):
        l = label(css_class)
        self.box.pack_start(l, False, False, 0)
        self.updaters.append(lambda: l.set_markup(fn()))
        return l

    def widget(self, w, top_gap=0):
        w.set_margin_top(top_gap)
        self.box.pack_start(w, False, False, 0)
        if isinstance(w, Hoverable):
            self.drawables.append(w)
        return w

    def refresh(self):
        for u in self.updaters:
            u()
        for d in self.drawables:
            if hasattr(d, "sync"):
                d.sync()
            d.queue_draw()


class StatBar:
    MODULES = ("cpu", "gpu", "ram", "tmp", "net", "dsk")

    def __init__(self):
        self.s = Sampler()
        self.prefs = self.load_prefs()

        css = Gtk.CssProvider()
        css.load_from_path(os.path.join(HERE, "statbar.css"))
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css,
                                                 Gtk.STYLE_PROVIDER_PRIORITY_USER)

        self.current = None
        self.show_timer = self.hide_timer = None
        self.build_strip()
        self.build_workspaces()
        self.panels = {m: getattr(self, f"panel_{m}")() for m in self.MODULES}
        self.windows = {m: self.build_panel_window(p) for m, p in self.panels.items()}

        threading.Thread(target=self.sample_loop, daemon=True).start()

    # ----- prefs -----

    def load_prefs(self):
        try:
            with open(PREFS) as f:
                return json.load(f)
        except (OSError, ValueError):
            return {}

    def save_prefs(self):
        try:
            with open(PREFS, "w") as f:
                json.dump(self.prefs, f)
        except OSError:
            pass

    # ----- sampling -----

    def reload_config(self):
        try:
            mtime = os.stat(CONFIG).st_mtime
        except OSError:
            mtime = None
        if mtime == self.config_mtime:
            return
        self.config_mtime = mtime
        CFG.update(load_config())
        with LOCK:
            self.s.set_points(CFG["graph_points"])

    def sample_loop(self):
        self.config_mtime = False
        time.sleep(0.5)
        next_graph = time.monotonic()
        while True:
            self.reload_config()
            start = time.monotonic()
            with LOCK:
                self.s.sample()
                if start >= next_graph:
                    self.s.push_graph()
                    next_graph = max(next_graph + CFG["graph_interval"], start)
            GLib.idle_add(self.refresh)
            time.sleep(max(0.05, CFG["stat_interval"] - (time.monotonic() - start)))

    def refresh(self):
        with LOCK:
            for m in self.MODULES:
                text, critical = getattr(self, f"text_{m}")()
                lbl = self.labels[m]
                name, _, value = text.partition(" ")   # tint only the "CPU"/"NET"… prefix
                lbl.set_markup(f"{span(name, LABEL)} {esc(value)}")
                ctx = lbl.get_style_context()
                (ctx.add_class if critical else ctx.remove_class)("critical")
            if self.current:
                self.panels[self.current].refresh()
        return False

    # ----- layer-shell windows -----

    def layer_window(self, namespace, layer):
        win = Gtk.Window()
        visual = win.get_screen().get_rgba_visual()
        if visual:
            win.set_visual(visual)
        GtkLayerShell.init_for_window(win)
        GtkLayerShell.set_namespace(win, namespace)
        GtkLayerShell.set_layer(win, layer)
        GtkLayerShell.set_exclusive_zone(win, -1)   # position from the screen edge, not below waybar
        GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)
        return win

    def build_strip(self):
        win = self.strip = self.layer_window("statbar", GtkLayerShell.Layer.TOP)
        win.set_name("strip")
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP, BAR_TOP)
        GtkLayerShell.set_margin(win, GtkLayerShell.Edge.RIGHT, BAR_RIGHT)
        win.set_size_request(-1, BAR_HEIGHT)

        box = Gtk.Box(spacing=8)
        self.labels, self.events = {}, {}
        for m in self.MODULES:
            lbl = Gtk.Label(label=m.upper())
            lbl.set_name(m)
            lbl.get_style_context().add_class("module")
            ev = Gtk.EventBox()
            ev.add(lbl)
            ev.connect("enter-notify-event", lambda _w, _e, m=m: self.on_module_enter(m))
            ev.connect("leave-notify-event", lambda _w, _e: self.schedule_hide())
            box.pack_start(ev, False, False, 0)
            self.labels[m], self.events[m] = lbl, ev
        win.add(box)
        win.show_all()

    def build_workspaces(self):
        win = self.ws_strip = self.layer_window("statbar", GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP, BAR_TOP)
        GtkLayerShell.set_margin(win, GtkLayerShell.Edge.LEFT, BAR_LEFT)
        win.set_size_request(-1, BAR_HEIGHT)
        win.add(Workspaces())
        win.show_all()

    def build_panel_window(self, panel):
        win = self.layer_window("statbar-panel", GtkLayerShell.Layer.TOP)
        win.get_style_context().add_class("panel-window")
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP, BAR_TOP + BAR_HEIGHT + PANEL_GAP)
        win.add(panel.box)
        win.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK)
        win.connect("enter-notify-event", lambda *_: self.cancel_hide())
        win.connect("leave-notify-event", self.on_panel_leave)
        panel.box.show_all()
        return win

    # ----- hover state -----

    def on_module_enter(self, m):
        self.cancel_hide()
        if self.show_timer:
            GLib.source_remove(self.show_timer)
            self.show_timer = None
        if self.current:            # already browsing: switch immediately
            if self.current != m:
                self.show(m)
        else:
            self.show_timer = GLib.timeout_add(SHOW_DELAY, self.show, m)

    def on_panel_leave(self, _w, ev):
        if ev.detail != Gdk.NotifyType.INFERIOR:   # moving onto a child widget isn't leaving
            self.schedule_hide()

    def schedule_hide(self):
        if self.show_timer:
            GLib.source_remove(self.show_timer)
            self.show_timer = None
        self.cancel_hide()
        self.hide_timer = GLib.timeout_add(HIDE_DELAY, self.hide)

    def cancel_hide(self):
        if self.hide_timer:
            GLib.source_remove(self.hide_timer)
            self.hide_timer = None

    def show(self, m):
        self.show_timer = None
        if self.current and self.current != m:
            self.windows[self.current].hide()
        self.current = m
        with LOCK:
            self.panels[m].refresh()
        win, ev = self.windows[m], self.events[m]
        monitor = Gdk.Display.get_default().get_monitor_at_window(self.strip.get_window())
        GtkLayerShell.set_monitor(win, monitor)
        geo = monitor.get_geometry()
        a = ev.get_allocation()
        strip_x = geo.width - BAR_RIGHT - self.strip.get_allocated_width()
        pw = win.get_preferred_width()[1]
        x = strip_x + a.x + a.width / 2 - pw / 2
        x = max(BAR_RIGHT, min(x, geo.width - pw - BAR_RIGHT))
        GtkLayerShell.set_margin(win, GtkLayerShell.Edge.LEFT, int(x))
        win.show()
        return False

    def hide(self):
        self.hide_timer = None
        if self.current:
            self.windows[self.current].hide()
            self.current = None
        return False

    # ----- bar texts -----

    def text_cpu(self):
        v = self.s.now.get("cpu")
        return (f"CPU {v:.0f}%" if v is not None else "CPU --"), False

    def text_gpu(self):
        g = self.s.gpu
        return (f"GPU {g['util']:.0f}%" if g else "GPU --"), False

    def text_ram(self):
        v = self.s.now.get("ram")
        return (f"RAM {v:.0f}%" if v is not None else "RAM --"), False

    def text_tmp(self):
        c = self.s.now.get("cpu_temp")
        g = self.s.gpu["temp"] if self.s.gpu else None
        return f"TMP {deg(c)} | {deg(g)}", (c or 0) >= HOT or (g or 0) >= HOT

    # unit prefs: network "bits"/"bytes", storage "iec" (GiB, 1024) / "si" (GB, 1000)
    def net_bytes(self):
        return self.prefs.get("net_unit", "bits") == "bytes"

    def rate(self, v):
        return fmt_rate(v, "B") if self.net_bytes() else fmt_rate(v * 8, "b")

    def disk_base(self):
        return 1000 if self.prefs.get("disk_unit", "iec") == "si" else 1024

    def size(self, n):
        return fmt_size(n, self.disk_base())

    def disk_rate(self, v):
        return fmt_rate(v, "B", self.disk_base())

    def unit_selector(self, key, options, default):
        """Row of text buttons; the selected one is bold and bright."""
        row = Gtk.Box(spacing=0)
        row.pack_start(dim_label("units  "), False, False, 0)
        labels = {}

        def render():
            cur = self.prefs.get(key, default)
            for value, (lbl, text) in labels.items():
                weight, color = ("bold", "#e8e8e8") if value == cur else ("normal", DIM)
                lbl.set_markup(f"<span weight='{weight}' foreground='{color}'>{text}</span>")

        def choose(value):
            self.prefs[key] = value
            self.save_prefs()
            render()
            self.refresh()
            if self.current:
                self.panels[self.current].refresh()

        for i, (value, text) in enumerate(options):
            if i:
                row.pack_start(dim_label(" · "), False, False, 0)
            ev = Gtk.EventBox()
            lbl = label()
            ev.add(lbl)
            ev.connect("button-press-event", lambda *_a, v=value: choose(v))
            ev.connect("realize", lambda w: w.get_window().set_cursor(
                Gdk.Cursor.new_from_name(w.get_display(), "pointer")))
            row.pack_start(ev, False, False, 0)
            labels[value] = (lbl, text)
        render()
        return row

    def text_net(self):
        s = self.s
        if not s.iface:
            return "NET down", False
        if "rx" not in s.now:
            return "NET …", False
        return f"NET {self.rate(s.now['tx'])} ↑ {self.rate(s.now['rx'])} ↓", False

    def text_dsk(self):
        root = next((f for f in self.s.fs if "/" in f["mounts"]), None)
        return (f"DSK {self.size(root['used'])} / {self.size(root['free'])}" if root else "DSK --"), False

    # ----- panels -----

    def core_items(self, values):
        e = self.s.e_cores
        return [(str(i), v, RED if i in e else BLUE,
                 f"Core {i} · {'E' if i in e else 'P'}-core") for i, v in values]

    def legend(self, a, b):
        return f"   {span('●', BLUE)} {a}   {span('●', RED)} {b}"

    def panel_cpu(self):
        s, p, c = self.s, Panel(), TINT["cpu"]
        p.text(lambda: span(esc(s.cpu_name), c), "title")
        p.text(lambda: stats_markup(s.now.get("cpu"), s.hist["cpu"], pct))
        p.widget(Graph(lambda: [("", list(s.hist["cpu"]), c)], pct, pct, top=100), 4)
        p.text(lambda: "Per core" + (self.legend("P-core", "E-core") if s.e_cores else ""), "heading")
        p.widget(Bars(lambda: self.core_items(enumerate(s.cpu_cores)), pct, pct))
        return p

    def panel_gpu(self):
        s, p, c = self.s, Panel(), TINT["gpu"]
        p.text(lambda: span(esc(s.gpu_name or "No NVIDIA GPU"), c), "title")
        p.text(lambda: (dim("VRAM ") + f"{s.gpu['vram_used']:.1f} / {s.gpu['vram_total']:.1f} GiB" +
                        dim("   power ") + f"{s.gpu['power']:.0f} W" +
                        dim("   temp ") + deg(s.gpu["temp"])) if s.gpu else dim("nvidia-smi unavailable"))
        p.text(lambda: stats_markup(s.now.get("gpu"), s.hist["gpu"], pct))
        p.widget(Graph(lambda: [("", list(s.hist["gpu"]), c)], pct, pct, top=100), 4)
        p.text(lambda: "Engines", "heading")
        engines = ("Core", "Memory", "Encoder", "Decoder")
        keys = ("util", "mem_util", "enc", "dec")
        p.widget(Bars(lambda: [(n, s.gpu[k] if s.gpu else 0, c, f"{n} utilization")
                               for n, k in zip(engines, keys)], pct, pct))
        return p

    def panel_ram(self):
        s, p, c = self.s, Panel(), TINT["ram"]
        p.text(lambda: span("Memory", c) + f"  {s.mem.get('used', 0):.1f} / {s.mem.get('total', 0):.1f} GiB", "title")
        p.text(lambda: dim("cached ") + f"{s.mem.get('cached', 0):.1f} GiB" + dim("   swap ") +
               f"{s.mem.get('swap_used', 0):.1f} / {s.mem.get('swap_total', 0):.1f} GiB")
        p.text(lambda: stats_markup(s.now.get("ram"), s.hist["ram"], pct))
        p.widget(Graph(lambda: [("", list(s.hist["ram"]), c)], pct, pct, top=100), 4)
        return p

    def panel_tmp(self):
        s, p, c = self.s, Panel(), TINT["tmp"]
        p.text(lambda: span("Temperatures", c) + self.legend("CPU", "GPU"), "title")

        def info():
            parts = []
            if s.core_temps:
                hot = max(s.core_temps, key=s.core_temps.get)
                parts.append(span("CPU ", BLUE) + dim("package ") + deg(s.package_temp) +
                             dim("  hottest ") + deg(s.core_temps[hot]) + dim(f" (core {hot})"))
            if s.gpu:
                parts.append(span("GPU ", RED) + deg(s.gpu["temp"]) + dim("  fan ") +
                             f"{s.gpu['fan']:.0f}%" + dim("  power ") + f"{s.gpu['power']:.0f} W")
            return "\n".join(parts)
        p.text(info)
        p.widget(Graph(lambda: [("CPU", list(s.hist["cpu_temp"]), BLUE), ("GPU", list(s.hist["gpu_temp"]), RED)],
                       deg, deg, top=100, bottom=20), 4)
        p.text(lambda: "Per core" + (self.legend("P-core", "E-core") if s.e_cores else ""), "heading")
        p.widget(Bars(lambda: self.core_items(sorted(s.core_temps.items())), deg, deg,
                      top=100, bottom=20))
        p.text(lambda: dim("Other   ") + "   ".join(f"{dim(n)} {deg(t)}" for n, t in s.other_temps))
        return p

    def panel_net(self):
        s, p, c = self.s, Panel(), TINT["net"]
        p.text(lambda: span("Network", c) + f"  {esc(s.iface or 'no route')}", "title")

        p.widget(self.unit_selector("net_unit", (("bits", "bits/s"), ("bytes", "bytes/s")), "bits"), 2)

        mult = lambda: 1 if self.net_bytes() else 8
        axis = lambda v: fmt_axis(v)
        for title, key, color in (("Download", "rx", BLUE), ("Upload", "tx", RED)):
            p.text(lambda t=title, col=color: span(t, col), "heading")
            p.text(lambda k=key: stats_markup(s.now.get(k), s.hist[k], self.rate))
            p.widget(Graph(lambda k=key, col=color: [("", [v * mult() for v in s.hist[k]], col)],
                           lambda v: fmt_rate(v, "B" if mult() == 1 else "b"), axis, height=90))
        return p

    def panel_dsk(self):
        s, p, c = self.s, Panel(), TINT["dsk"]
        p.text(lambda: span("Disk", c) + "  " + "  ".join(
            esc(d) + (dim(" " + esc(s.disk_models[d])) if s.disk_models[d] else "") for d in s.disks), "title")
        p.widget(self.unit_selector("disk_unit", (("iec", "GiB (1024)"), ("si", "GB (1000)")), "iec"), 2)
        axis = lambda v: fmt_axis(v, self.disk_base())
        ceil = lambda v: nice_ceiling(v, 1000.0, self.disk_base())
        for title, key, color in (("Read", "rd", BLUE), ("Write", "wr", RED)):
            p.text(lambda t=title, col=color: span(t, col), "heading")
            p.text(lambda k=key: stats_markup(s.now.get(k), s.hist[k], self.disk_rate))
            p.widget(Graph(lambda k=key, col=color: [("", list(s.hist[k]), col)], self.disk_rate, axis,
                           height=90, ceil=ceil))
        p.text(lambda: "Filesystems", "heading")
        p.widget(FsList(lambda: s.fs, c, self.size), 2)
        return p


def dim_label(text):
    l = label()
    l.set_markup(dim(text))
    return l


def main():
    lock = open(os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "statbar.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit("statbar is already running")
    StatBar()
    Gtk.main()


if __name__ == "__main__":
    main()
