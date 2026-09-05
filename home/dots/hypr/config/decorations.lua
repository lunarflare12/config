hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 8,
        border_size = 2,
        resize_on_border = false,
        allow_tearing = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 14,
        rounding_power = 5,
        active_opacity = 1,
        fullscreen_opacity = 1,
        shadow = { enabled = false },
        blur = { enabled = true },
    },
    dwindle = { preserve_split = true },
    master = { new_status = "master", mfact = 0.7 },
    render = {
        direct_scanout = 2,
        cm_enabled = false,
        send_content_type = false,
    },
    opengl = {
        nvidia_anti_flicker = false,
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        middle_click_paste = false,
        vrr = 0,
    },
    binds = {
        disable_keybind_grabbing = true,
    },
})
