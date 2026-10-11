"""Hyprland workspace buttons with window icons (waybar 0.15 sees no windows on Hyprland 0.56)."""
import json
import os
import socket
import threading
import time

from gi.repository import Gio, GLib, Gtk

PERSISTENT = 5   # workspaces 1..N are always shown
ICON_SIZE = 16


def hypr_dir():
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "hypr",
                        os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""))


def hypr_request(cmd):
    """Raw request over Hyprland's command socket (what hyprctl does)."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(os.path.join(hypr_dir(), ".socket.sock"))
        s.sendall(cmd.encode())
        chunks = []
        while chunk := s.recv(65536):
            chunks.append(chunk)
    return b"".join(chunks)


def hypr_query(cmd):
    """JSON request, e.g. 'j/clients'."""
    return json.loads(hypr_request(cmd) or b"null")


_icon_cache = {}


def desktop_info(name):
    """DesktopAppInfo for name.desktop, or None (PyGObject raises instead of returning NULL)."""
    try:
        return Gio.DesktopAppInfo.new(f"{name}.desktop")
    except TypeError:
        return None


def icon_for_class(cls):
    """GIcon for a window class, via its .desktop file when one matches."""
    cls = cls or ""
    if cls in _icon_cache:
        return _icon_cache[cls]
    icon = None
    for name in dict.fromkeys((cls, cls.lower(), cls.split(".")[-1].lower())):
        info = desktop_info(name) if name else None
        if info and info.get_icon():
            icon = info.get_icon()
            break
    if icon is None:
        for info in Gio.AppInfo.get_all():
            if cls and isinstance(info, Gio.DesktopAppInfo) and (info.get_startup_wm_class() or "").lower() == cls.lower():
                icon = info.get_icon()
                break
    if icon is None and cls and Gtk.IconTheme.get_default().has_icon(cls.lower()):
        icon = Gio.ThemedIcon.new(cls.lower())
    _icon_cache[cls] = icon or Gio.ThemedIcon.new("application-x-executable")
    return _icon_cache[cls]


class Workspaces(Gtk.Box):
    REFRESH_EVENTS = ("workspace", "focusedmon", "openwindow", "closewindow", "movewindow",
                      "createworkspace", "destroyworkspace", "activewindowv2", "windowtitlev2",
                      "changefloatingmode", "monitoradded", "monitorremoved")

    def __init__(self):
        super().__init__(spacing=0)
        self.set_name("workspaces")
        self.pending = False
        self.rebuild()
        threading.Thread(target=self.listen, daemon=True).start()

    def listen(self):
        while True:
            try:
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                    s.connect(os.path.join(hypr_dir(), ".socket2.sock"))
                    buf = b""
                    while chunk := s.recv(4096):
                        buf += chunk
                        *lines, buf = buf.split(b"\n")
                        if any(l.split(b">>")[0].decode(errors="ignore") in self.REFRESH_EVENTS for l in lines):
                            GLib.idle_add(self.schedule)
            except OSError:
                pass
            time.sleep(2)

    def schedule(self):
        if not self.pending:   # coalesce bursts of events into one rebuild
            self.pending = True
            GLib.timeout_add(50, self.rebuild)
        return False

    def rebuild(self):
        self.pending = False
        try:
            clients = hypr_query("j/clients")
            workspaces = hypr_query("j/workspaces")
            monitors = hypr_query("j/monitors")
            active_win = hypr_query("j/activewindow") or {}
        except (OSError, ValueError):
            return False
        active = {m["activeWorkspace"]["id"] for m in monitors if m.get("focused")}
        ids = sorted({w["id"] for w in workspaces if w["id"] > 0} | set(range(1, PERSISTENT + 1)))
        by_ws = {}
        for c in sorted(clients, key=lambda c: (c["at"][0], c["at"][1])):
            if c.get("mapped", True) and not c.get("hidden"):
                by_ws.setdefault(c["workspace"]["id"], []).append(c)

        buttons = []
        for wid in ids:
            btn = Gtk.Button()
            btn.set_relief(Gtk.ReliefStyle.NONE)
            ctx = btn.get_style_context()
            if wid in active:
                ctx.add_class("active")
            if not by_ws.get(wid):
                ctx.add_class("empty")
            inner = Gtk.Box(spacing=4)
            inner.pack_start(Gtk.Label(label=str(wid)), False, False, 0)
            for c in by_ws.get(wid, []):
                try:
                    gicon = icon_for_class(c["class"])
                except Exception:
                    gicon = Gio.ThemedIcon.new("application-x-executable")
                img = Gtk.Image.new_from_gicon(gicon, Gtk.IconSize.MENU)
                img.set_pixel_size(ICON_SIZE)
                img.set_tooltip_text(c["title"] or c["class"])
                if c["address"] == active_win.get("address"):
                    img.get_style_context().add_class("focused")
                inner.pack_start(img, False, False, 0)
            btn.add(inner)
            btn.connect("clicked", lambda _b, w=wid: hypr_request(f"dispatch hl.dsp.focus({{ workspace = {w} }})"))
            buttons.append(btn)
        for child in self.get_children():
            self.remove(child)
        for btn in buttons:
            self.pack_start(btn, False, False, 0)
        self.show_all()
        return False
