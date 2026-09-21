local game_flag = io.open("/home/dd/.local/state/aurora-game", "r")
local playing = game_flag ~= nil
if game_flag then
    game_flag:close()
end

hl.config({
    general = {
        -- Keep desktop chrome even if aurora-game is left behind. Games already
        -- get border_size 0 + fullscreen via window rules.
        gaps_in = 4,
        gaps_out = { top = 4, right = 10, bottom = 10, left = 10 },
        border_size = 4,
        resize_on_border = false,
        allow_tearing = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 0,
        rounding_power = 2,
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
            -- Games already set no_blur. Keep compositor blur so Kitty's
            -- background_blur protocol still works if aurora-game is leftover.
            enabled = true,
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
        -- Never globally. Overwatch 1920→2560 is toggled in windows.lua
        -- when that window is focused; otherwise Steam CEF clicks miss.
        expand_undersized_textures = false,
        send_content_type = playing,
        -- Triple-buffer scheduling made 1% lows worse on 200Hz+60Hz NVIDIA.
        new_render_scheduling = false,
    },
    opengl = {
        nvidia_anti_flicker = false,
    },
    cursor = {
        hide_on_key_press = false,
        -- Software cursor on the desktop. CPU-buffer HW cursors pass a -1x-1
        -- damage rect on this NVIDIA driver and SIGSEGV Hyprland.
        no_hardware_cursors = true,
        use_cpu_buffer = false,
        enable_hyprcursor = false,
        default_monitor = "DP-1",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        middle_click_paste = false,
        mouse_move_focuses_monitor = not playing,
        -- Xiaomi DP-1 is not VRR-capable. vrr=2 waits on a signal that
        -- never comes and hitchs a 205 FPS cap.
        vrr = 0,
        render_unfocused_fps = playing and 205 or 15,
    },
    debug = {
        -- Mixed 200Hz + 60Hz NVIDIA: VFR emits empty damage rects and hitches.
        vfr = false,
        render_solitary_wo_damage = playing,
    },
    binds = {
        disable_keybind_grabbing = true,
    },
})
