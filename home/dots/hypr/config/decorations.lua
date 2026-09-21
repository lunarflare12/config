local game_flag = io.open("/home/dd/.local/state/aurora-game", "r")
local in_game = game_flag ~= nil
if game_flag then
    game_flag:close()
end

hl.config({
    general = {
        gaps_in = in_game and 0 or 4,
        gaps_out = in_game and { top = 0, right = 0, bottom = 0, left = 0 } or { top = 4, right = 10, bottom = 10, left = 10 },
        border_size = in_game and 0 or 4,
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
            enabled = not in_game,
            range = 36,
            render_power = 4,
            color = "rgba(000000a8)",
            offset = "0 10",
        },
        blur = {
            enabled = not in_game,
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
        -- Needed so immediate/tearing window rules actually mark the game.
        -- Plugin reports 1920x1080; stretch that buffer onto the 2560 window.
        expand_undersized_textures = true,
        send_content_type = in_game,
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
        mouse_move_focuses_monitor = not in_game,
        -- Xiaomi DP-1 is not VRR-capable. vrr=2 waits on a signal that
        -- never comes and hitchs a 205 FPS cap.
        vrr = 0,
        render_unfocused_fps = in_game and 205 or 15,
    },
    debug = {
        -- Mixed 200Hz + 60Hz NVIDIA: VFR emits empty damage rects and hitches.
        vfr = false,
        render_solitary_wo_damage = in_game,
    },
    binds = {
        disable_keybind_grabbing = true,
    },
})
