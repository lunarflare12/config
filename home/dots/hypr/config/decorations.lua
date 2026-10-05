local home = os.getenv("HOME") or "/home/dd"
local game_flag = io.open(home .. "/.local/state/aurora-game", "r")
local playing = game_flag ~= nil
if game_flag then
    game_flag:close()
end

hl.config({
    general = {
        -- Keep desktop chrome even if aurora-game is left behind. Games already
        -- get border_size 0 + fullscreen via window rules.
        gaps_in = 6,
        -- Top is tighter: the bar already reserves notchHeight, so a full
        -- gaps_out there stacked into a band wider than the sides. Sides
        -- keep 10 so the aurora frame (frameWidth) + wallpaper pad match.
        gaps_out = { top = 7, right = 10, bottom = 10, left = 10 },
        -- Thinner than the old 4 — still the real per-window outline.
        -- Aurora frame is screen chrome, not a substitute for this.
        border_size = 2,
        resize_on_border = false,
        allow_tearing = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 16,
        -- 2 left hairline gaps in the stroke at the arc→flat join.
        rounding_power = 1,
        active_opacity = 1,
        fullscreen_opacity = 1,
        shadow = {
            enabled = not playing,
            range = 36,
            render_power = 4,
            color = "rgba(000000a8)",
            offset = "0 10",
        },
        blur = {
            -- Off while a game flag is present so a reload does not put
            -- three-pass blur back over the 1920→2560 stretch.
            enabled = not playing,
            size = 8,
            passes = 3,
            xray = false,
            popups = false,
            ignore_opacity = true,
        },
    },
    dwindle = { preserve_split = true },
    master = { new_status = "master", mfact = 0.7 },
    render = {
        -- Auto scanout on NVIDIA exclusive FS blanks the other output.
        direct_scanout = 0,
        cm_enabled = false,
        -- Never globally: undersized texture expand breaks Steam CEF hit-testing.
        expand_undersized_textures = false,
        send_content_type = false,
        -- Triple-buffer scheduling made 1% lows worse on 200Hz+60Hz NVIDIA.
        new_render_scheduling = false,
    },
    opengl = {
        nvidia_anti_flicker = false,
    },
    cursor = {
        hide_on_key_press = false,
        -- 0.56 defaults no_hardware_cursors to 2 (auto). On this NVIDIA
        -- driver a HW cursor still sends a -1x-1 damage rect and SIGSEGV
        -- Hyprland — keep software cursors. Hyprcursor themes also trip it.
        no_hardware_cursors = true,
        use_cpu_buffer = false,
        enable_hyprcursor = false,
        -- Connector name jumps DP-1↔DP-4; hyprfix resolves the live one.
        default_monitor = "DP-1",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        middle_click_paste = false,
        -- Always on. GameMode used to flip this off for the whole session
        -- and the second monitor stopped taking focus until the game quit.
        mouse_move_focuses_monitor = true,
        -- Xiaomi ultrawide is not VRR-capable. vrr=2 waits on a signal that
        -- never comes and hitchs a high FPS cap.
        vrr = 0,
        render_unfocused_fps = 15,
    },
    debug = {
        -- Mixed 200Hz + 60Hz NVIDIA: VFR emits empty damage rects and hitches.
        vfr = false,
        render_solitary_wo_damage = false,
    },
    binds = {
        disable_keybind_grabbing = true,
    },
})
