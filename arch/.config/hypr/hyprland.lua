-- ~/.config/hypr/hyprland.lua
-- Converted from hyprland.conf (Hyprland 0.55+ Lua format)
--
-- Lines marked [VERIFY] use dispatcher/field names I could not confirm
-- against the wiki. Check them with:  hyprctl repl
--   > for k in pairs(hl.dsp) do print(k) end
--   > for k in pairs(hl.dsp.window) do print(k) end
-- or let the LSP autocomplete them.

local mainMod = "SUPER"
local home = os.getenv("HOME")

--------------------------------------------------------------------
-- Monitor
--------------------------------------------------------------------
-- [VERIFY] field names for hl.monitor
hl.monitor({
    output     = "",                -- empty = fallback rule for any output
    mode     = "3440x1440@100",
    position = "auto",
    scale    = 1,
})

--------------------------------------------------------------------
-- Core settings
--------------------------------------------------------------------

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 1,
        col = {
            active_border   = "rgba(ffffff66)",
            inactive_border = "rgba(ffffff22)",
        },
    },

    decoration = {
        rounding = 0,
    },

    input = {
        kb_layout    = "us",
        kb_options   = "korean:ralt_hangul",   -- Right Alt sends Hangul
        repeat_rate  = 45,
        repeat_delay = 200,
    },

    animations = {
        enabled = true,
    },
})

--------------------------------------------------------------------
-- Animations
--------------------------------------------------------------------
hl.curve("soft", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })

local function anim(leaf, speed, style)
    hl.animation({
        leaf    = leaf,
        enabled = true,
        speed   = speed,
        bezier  = "soft",
        style   = style,
    })
end

anim("windows",    2, "popin 0%")
anim("windowsIn",  2, "popin 0%")
anim("windowsOut", 2, "popin 0%")
anim("fade",       2, nil)
anim("workspaces", 3, "slidefade 10%")

--------------------------------------------------------------------
-- Window rules
--------------------------------------------------------------------
local function rule(name, match, effects)
    local r = { name = name, match = match }
    for k, v in pairs(effects) do r[k] = v end
    hl.window_rule(r)
end

-- floating + undecorated, reused by three rules below
local bare = {
    float     = true,
    decorate  = false,
    no_blur   = true,
    no_shadow = true,
}

rule("game", { content = "game" }, {
    float       = true,
    decorate    = false,
    border_size = 0,
    rounding    = 0,
    no_blur     = true,
    no_shadow   = true,
    opaque      = true,
    force_rgbx  = true,
})

rule("adofai",  { class = "ADanceOfFireAndIce" }, { float = true })
rule("dm-note", { class = "dm-note" },            bare)
rule("zoom",    { class = "zoom" },               bare)

--------------------------------------------------------------------
-- Korean input (fcitx5)
--------------------------------------------------------------------
-- GTK apps use Wayland text-input-v3 natively, so GTK_IM_MODULE stays unset.
hl.env("XMODIFIERS",    "@im=fcitx")   -- XWayland apps
hl.env("QT_IM_MODULE",  "fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Toggle Korean/English from the compositor. This fires before fcitx's own
-- keyboard grab, so it works even when fcitx never sees the Hangul key.
hl.bind("Hangul", hl.dsp.exec_cmd("fcitx5-remote -t"))

-- Never let fcitx5's popups take focus
hl.window_rule({
  name  = "fcitx-no-focus",
  match = { class = "^(fcitx)$" },
  no_focus = true,
  no_initial_focus = true,
})

--------------------------------------------------------------------
-- Launchers
--------------------------------------------------------------------
local browser = "brave --enable-wayland-ime --enable-features=UseOzonePlatform --ozone-platform=wayland"
local discord = "vesktop --enable-wayland-ime --enable-features=UseOzonePlatform --ozone-platform=wayland"

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + V",      hl.dsp.exec_cmd(discord))
hl.bind("CTRL + ALT + Escape",  hl.dsp.exec_cmd("wlogout -m 450"))

hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(
    "fuzzel --config " .. home .. "/.config/fuzzel/launcher.ini"))

hl.bind(mainMod .. " + period", hl.dsp.exec_cmd(
    home .. "/.local/bin/emoji-picker --selector "
    .. "'fuzzel --config " .. home .. "/.config/fuzzel/emoji.ini'"))

hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(
    "rofi -show wallpaper"
    .. " -modi wallpaper:" .. home .. "/.config/hypr/scripts/rofi-wallpaper"
    .. " -theme " .. home .. "/.config/rofi/wallpaper.rasi"))

--------------------------------------------------------------------
-- Window management
--------------------------------------------------------------------
hl.bind(mainMod .. " + Q",     hl.dsp.window.close())              -- [VERIFY] was killactive
hl.bind(mainMod .. " + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",     hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + C",     hl.dsp.window.center())             -- [VERIFY] was centerwindow

-- Your old hyprctl|jq pipeline, now native. No subprocess, no jq dependency.
hl.bind(mainMod .. " + SHIFT + Q", function()
    local w = hl.get_active_window()
    if w ~= nil then
        hl.dispatch(hl.dsp.exec_cmd("kill " .. w.pid))              -- [VERIFY] .pid field
    end
end)

-- Mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Vim-style focus / move                                  [VERIFY] both dispatchers
local dirs = { H = "l", J = "d", K = "u", L = "r" }
for key, dir in pairs(dirs) do
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ direction = dir }))
end

--------------------------------------------------------------------
-- Workspaces
--------------------------------------------------------------------
for i = 1, 10 do
    local key = tostring(i % 10)
    local ws  = tostring(i)

    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = ws }))
    hl.bind(mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = ws }))
    hl.bind("ALT + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = ws, silent = true }))
end

--------------------------------------------------------------------
-- Screenshots
--------------------------------------------------------------------
hl.bind(mainMod .. " + SHIFT + S",     hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind(mainMod .. " + Print",         hl.dsp.exec_cmd("hyprshot -m window"))
-- pipeline needs a shell
hl.bind(mainMod .. " + SHIFT + Print",
    hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | swappy -f -'"))

--------------------------------------------------------------------
-- Media / hardware keys
--------------------------------------------------------------------
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })

-- External monitor brightness over DDC/CI
hl.bind(mainMod .. " + Up",   hl.dsp.exec_cmd("ddcutil setvcp 10 + 5 --noverify"), { repeating = true })
hl.bind(mainMod .. " + Down",   hl.dsp.exec_cmd("ddcutil setvcp 10 - 5 --noverify"), { repeating = true })
--------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------
-- Everything runs through sh so ~ and $(...) expand, and each command's
-- output goes to ~/.cache/hypr-startup.log so failures are visible.
local startlog = home .. "/.cache/hypr-startup.log"

local function start(cmd)
    local script = "{ " .. cmd .. "; } >>" .. startlog .. " 2>&1"
    hl.exec_cmd("sh -c '" .. script:gsub("'", [['\'']]) .. "'")
end

-- One handler only: a second hl.on for the same event may replace the first.
hl.on("hyprland.start", function()
    os.remove(startlog)
    start("waybar")
    start("systemctl --user start hyprpolkitagent")
    start("swayosd-server")
    start("~/.config/hypr/scripts/no-repeat.sh")
    start("~/.local/bin/chromium-wayland-flags")
    start([[swaybg -i "$(grep '^wallpaper' ~/.config/hypr/hyprpaper.conf | cut -d, -f2 | tr -d ' ')" -m fill]])
    -- give the compositor a moment so fcitx finds the input-method protocol
    start("sleep 1; exec fcitx5 -d --replace")
end)
