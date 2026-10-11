"""System data collection for statbar.

Sampler.sample() runs every stat interval and updates the live values in `now`;
Sampler.push_graph() runs every graph interval and appends the average of the
samples since the last push to each `hist` deque.
"""
import glob
import os
import re
import subprocess
import time
from collections import deque

HISTORY = 60  # default graph points kept
SERIES = ("cpu", "gpu", "ram", "cpu_temp", "gpu_temp", "rx", "tx", "rd", "wr")


def read(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def num(s, default=0.0):
    try:
        return float(s)
    except (TypeError, ValueError):
        return default


# ---------- formatting ----------

def _scale(v, base):
    i = 0
    while v >= base - 0.5 and i < 4:
        v /= base
        i += 1
    return v, i


def _sig3(v):
    return f"{v:.2f}" if v < 9.995 else f"{v:.1f}" if v < 99.95 else f"{v:.0f}"


def fmt_rate(v, unit="b", base=1000):
    """3 significant digits: '24.9 kb/s', '3.11 kB/s', or with base 1024 '3.04 KiB/s'."""
    v, i = _scale(v, base)
    if i == 0:
        return f"{v:.0f} {unit}/s"
    prefix = ("k", "M", "G", "T")[i - 1] if base == 1000 else ("Ki", "Mi", "Gi", "Ti")[i - 1]
    return f"{_sig3(v)} {prefix}{unit}/s"


def fmt_axis(v, base=1000):
    """Compact axis label: 100k, 2M (or 512Ki with base 1024)."""
    v, i = _scale(v, base)
    prefix = ("", "k", "M", "G", "T")[i] if base == 1000 else ("", "Ki", "Mi", "Gi", "Ti")[i]
    return f"{v:g}{prefix}"


def fmt_size(n, base=1024):
    """Bytes -> '369.8GiB' (base 1024) or '397.1GB' (base 1000)."""
    n, i = _scale(n, base)
    units = ("B", "KiB", "MiB", "GiB", "TiB") if base == 1024 else ("B", "kB", "MB", "GB", "TB")
    return f"{n:.1f}{units[i]}"


def fmt_iec(n):
    return fmt_size(n, 1024)


def nice_ceiling(v, floor=1000.0, base=1000):
    """Round up to 1/2/5 x 10^n (times a power of `base`) for a readable graph scale."""
    if v <= floor:
        return floor
    mant, i = _scale(v, base)
    mag = 10 ** int(f"{mant:e}".split("e")[1])
    for m in (1, 2, 5, 10):
        if mant <= m * mag:
            return m * mag * base ** i
    return 10 * mag * base ** i


# ---------- CPU ----------

def cpu_name():
    with open("/proc/cpuinfo") as f:
        for line in f:
            if line.startswith("model name"):
                name = line.split(":", 1)[1].strip()
                return re.sub(r"\((R|TM)\)", "", name).replace("  ", " ")
    return "CPU"


def e_cores():
    cores = set()
    for part in (read("/sys/devices/cpu_atom/cpus") or "").split(","):
        if part:
            a, _, b = part.partition("-")
            cores.update(range(int(a), int(b or a) + 1))
    return cores


def read_cpu_times():
    times = {}
    with open("/proc/stat") as f:
        for line in f:
            if not line.startswith("cpu"):
                break
            name, *vals = line.split()
            vals = list(map(int, vals))
            times[name] = (vals[3] + vals[4], sum(vals))
    return times


# ---------- sensors ----------

def hwmons():
    return [(d, read(f"{d}/name", "")) for d in sorted(glob.glob("/sys/class/hwmon/hwmon*"))]


def core_temps():
    """(package temp, {cpu index: temp})."""
    by_core_id, package = {}, None
    for d, name in hwmons():
        if name not in ("coretemp", "k10temp", "zenpower"):
            continue
        for label_file in glob.glob(f"{d}/temp*_label"):
            label = read(label_file, "")
            value = read(label_file.replace("_label", "_input"))
            if value is None:
                continue
            t = int(value) / 1000
            if label.startswith(("Package", "Tctl")):
                package = t
            elif m := re.match(r"(?:Core|Tccd)\s*(\d+)", label):
                by_core_id[int(m.group(1))] = t
    per_cpu = {}
    for cpu_dir in glob.glob("/sys/devices/system/cpu/cpu[0-9]*"):
        core_id = read(f"{cpu_dir}/topology/core_id")
        if core_id is not None and int(core_id) in by_core_id:
            per_cpu[int(cpu_dir.rsplit("cpu", 1)[1])] = by_core_id[int(core_id)]
    return package, per_cpu


OTHER_SENSORS = {"nvme": "NVMe", "spd5118": "DIMM", "acpitz": "ACPI"}


def other_temps():
    out = []
    for d, name in hwmons():
        label = OTHER_SENSORS.get(name) or ("WiFi" if re.match(r"(mt7|iwl|ath)", name) else None)
        value = read(f"{d}/temp1_input")
        if label and value is not None:
            out.append((label, int(value) / 1000))
    return out


# ---------- GPU ----------

GPU_FIELDS = ("utilization.gpu,utilization.memory,utilization.encoder,utilization.decoder,"
              "memory.used,memory.total,power.draw,temperature.gpu,fan.speed")


def nvidia_query(fields):
    try:
        out = subprocess.run(
            ["nvidia-smi", f"--query-gpu={fields}", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=5,
        ).stdout
        return [[x.strip() for x in line.split(",")] for line in out.strip().splitlines()]
    except Exception:
        return []


# ---------- network / disk ----------

def default_iface():
    try:
        with open("/proc/net/route") as f:
            for line in f.readlines()[1:]:
                fields = line.split()
                if fields[1] == "00000000":
                    return fields[0]
    except OSError:
        pass
    return None


def iface_bytes(iface):
    with open("/proc/net/dev") as f:
        for line in f:
            name, _, rest = line.partition(":")
            if name.strip() == iface:
                vals = rest.split()
                return int(vals[0]), int(vals[8])
    return None


def physical_disks():
    return sorted(os.path.basename(p) for p in glob.glob("/sys/block/*")
                  if not os.path.basename(p).startswith(("loop", "zram", "ram", "dm-", "md", "sr")))


def disk_bytes(disks):
    rd = wr = 0
    with open("/proc/diskstats") as f:
        for line in f:
            fields = line.split()
            if fields[2] in disks:
                rd += int(fields[5]) * 512
                wr += int(fields[9]) * 512
    return rd, wr


def filesystems():
    """[{mounts, dev, total, used, free}] for real block devices, one per device."""
    seen = {}
    with open("/proc/mounts") as f:
        for line in f:
            dev, mnt = line.split()[:2]
            if not dev.startswith("/dev/") or dev.startswith("/dev/loop"):
                continue
            mnt = mnt.replace("\\040", " ")
            if dev in seen:
                seen[dev]["mounts"].append(mnt)
                continue
            try:
                st = os.statvfs(mnt)
            except OSError:
                continue
            seen[dev] = dict(mounts=[mnt], dev=dev, total=st.f_blocks * st.f_frsize,
                             used=(st.f_blocks - st.f_bfree) * st.f_frsize,
                             free=st.f_bavail * st.f_frsize)
    return list(seen.values())


# ---------- sampler ----------

class Sampler:
    """Holds histories; sample() refreshes everything. Rates are per second, bytes."""

    def __init__(self):
        self.cpu_name = cpu_name()
        self.e_cores = e_cores()
        q = nvidia_query("name")
        self.gpu_name = q[0][0] if q else None
        self.disks = physical_disks()
        self.disk_models = {d: read(f"/sys/block/{d}/device/model", "") for d in self.disks}

        self.now = {}                                         # live value per series
        self.hist = {k: deque(maxlen=HISTORY) for k in SERIES}   # graph points per series
        self._acc = {}                                        # series -> [sum(v*dt), sum(dt)]

        self.cpu_cores, self.core_temps, self.package_temp = [], {}, None
        self.gpu = None
        self.mem = {}
        self.other_temps = []
        self.iface = None
        self.fs = []

        self._cpu_prev = read_cpu_times()
        self._net_prev = None
        self._disk_prev = disk_bytes(self.disks)
        self._t_prev = time.monotonic()

    def set_points(self, n):
        """Change how many graph points are kept (keeps the newest ones)."""
        n = max(2, int(n))
        for k, h in self.hist.items():
            if h.maxlen != n:
                self.hist[k] = deque(h, maxlen=n)

    def _put(self, key, value, dt):
        self.now[key] = value
        acc = self._acc.setdefault(key, [0.0, 0.0])
        acc[0] += value * dt
        acc[1] += dt

    def push_graph(self):
        """Append the time-weighted average since the last push as one graph point."""
        for k, (total, weight) in self._acc.items():
            if weight > 0:
                self.hist[k].append(total / weight)
        self._acc.clear()

    def sample(self):
        now = time.monotonic()
        dt = max(now - self._t_prev, 1e-3)
        self._t_prev = now
        put = lambda k, v: self._put(k, v, dt)

        # CPU usage
        cur = read_cpu_times()
        usage = {}
        for k, (idle, total) in cur.items():
            p_idle, p_total = self._cpu_prev.get(k, (idle, total))
            d = total - p_total
            usage[k] = 0.0 if d <= 0 else 100.0 * (1 - (idle - p_idle) / d)
        self._cpu_prev = cur
        put("cpu", usage["cpu"])
        self.cpu_cores = [usage[f"cpu{i}"] for i in range(len(cur) - 1)]

        # temperatures
        self.package_temp, self.core_temps = core_temps()
        if self.core_temps:
            put("cpu_temp", sum(self.core_temps.values()) / len(self.core_temps))
        self.other_temps = other_temps()

        # GPU
        q = nvidia_query(GPU_FIELDS)
        if q:
            r = [num(x) for x in q[0]]
            self.gpu = dict(util=r[0], mem_util=r[1], enc=r[2], dec=r[3],
                            vram_used=r[4] / 1024, vram_total=r[5] / 1024,
                            power=r[6], temp=r[7], fan=r[8])
            put("gpu", r[0])
            put("gpu_temp", r[7])
        else:
            self.gpu = None

        # memory
        info = {}
        with open("/proc/meminfo") as f:
            for line in f:
                k, v = line.split(":", 1)
                info[k] = int(v.split()[0]) / 2**20
        used = info["MemTotal"] - info["MemAvailable"]
        self.mem = dict(used=used, total=info["MemTotal"], cached=info["Cached"],
                        swap_used=info["SwapTotal"] - info["SwapFree"], swap_total=info["SwapTotal"])
        put("ram", 100 * used / info["MemTotal"])

        # network
        iface = default_iface()
        net = iface_bytes(iface) if iface else None
        if net and self._net_prev and iface == self.iface:
            put("rx", (net[0] - self._net_prev[0]) / dt)
            put("tx", (net[1] - self._net_prev[1]) / dt)
        self.iface, self._net_prev = iface, net

        # disk
        d = disk_bytes(self.disks)
        put("rd", (d[0] - self._disk_prev[0]) / dt)
        put("wr", (d[1] - self._disk_prev[1]) / dt)
        self._disk_prev = d
        self.fs = filesystems()
