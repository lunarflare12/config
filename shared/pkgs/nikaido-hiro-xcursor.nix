{
  lib,
  stdenvNoCC,
  xorg,
  imagemagick,
}:

let
  src = ../../assets/cursors/nikaido-hiro;
  sizes = [
    32
    48
    64
    96
    128
    192
    256
  ];
in

stdenvNoCC.mkDerivation {
  pname = "nikaido-hiro-xcursor";
  version = "0.2";

  inherit src;

  nativeBuildInputs = [
    xorg.xcursorgen
    imagemagick
  ];

  dontUnpack = true;

  phases = [
    "installPhase"
    "fixupPhase"
  ];

  installPhase = ''
    runHook preInstall
    outCursors="$out/share/icons/nikaido-hiro/cursors"
    mkdir -p "$outCursors"
    tmpdir=$(mktemp -d)

    for cur in "$src"/Static/*.cur; do
      [[ -f "$cur" ]] || continue
      name=$(basename "$cur" .cur)

      width=$(od -An -tu1 -j6 -N1 "$cur" | tr -d ' ')
      [ "$width" -eq 0 ] && width=256
      xhot=$(od -An -tu2 -j10 -N2 --endian=little "$cur" | tr -d ' ')
      yhot=$(od -An -tu2 -j12 -N2 --endian=little "$cur" | tr -d ' ')

      conf="$tmpdir/$name.cfg"
      : > "$conf"
      for s in ${lib.concatStringsSep " " (map toString sizes)}; do
        png="$tmpdir/$name-$s.png"
        magick "$cur[0]" -resize "''${s}x''${s}" "$png"
        nxhot=$(( xhot * s / width ))
        nyhot=$(( yhot * s / width ))
        printf "%s %d %d %s\n" "$s" "$nxhot" "$nyhot" "$png" >> "$conf"
      done

      xcursorgen "$conf" "$outCursors/$name"
    done

    cd "$outCursors"
    ln -sf Normal left_ptr
    ln -sf Normal default
    ln -sf Normal top_left_arrow
    ln -sf Normal arrow
    ln -sf Normal right_ptr

    ln -sf Help help
    ln -sf Help whats_this

    ln -sf Working left_ptr_watch
    ln -sf Working progress

    ln -sf Busy watch
    ln -sf Busy wait

    ln -sf Precision crosshair
    ln -sf Precision tcross

    ln -sf Text text
    ln -sf Text xterm

    ln -sf Handwriting pencil

    ln -sf Unavailable not-allowed
    ln -sf Unavailable crossed_circle
    ln -sf Unavailable forbidden

    ln -sf Vertical sb_v_double_arrow
    ln -sf Vertical v_double_arrow
    ln -sf Vertical split_v
    ln -sf Vertical ns-resize
    ln -sf Vertical size_ver

    ln -sf Horizontal sb_h_double_arrow
    ln -sf Horizontal h_double_arrow
    ln -sf Horizontal split_h
    ln -sf Horizontal ew-resize
    ln -sf Horizontal size_hor

    ln -sf Diagonal1 nwse-resize
    ln -sf Diagonal1 fd_double_arrow
    ln -sf Diagonal1 bottom_right_corner
    ln -sf Diagonal1 ur_angle
    ln -sf Diagonal1 size_fdiag

    ln -sf Diagonal2 nesw-resize
    ln -sf Diagonal2 bd_double_arrow
    ln -sf Diagonal2 bottom_left_corner
    ln -sf Diagonal2 size_bdiag

    ln -sf Move fleur
    ln -sf Move move
    ln -sf Move all-scroll

    ln -sf Alternate based_arrow_up

    ln -sf Link hand2
    ln -sf Link pointer
    ln -sf Link pointing_hand
    ln -sf Link openhand
    ln -sf Link grab
    ln -sf Link closedhand

    ln -sf Person context-menu
    ln -sf Pin alias

    mkdir -p "$out/share/icons/nikaido-hiro"
    cat > "$out/share/icons/nikaido-hiro/index.theme" << 'EOF'
    [Icon Theme]
    Name=Nikaido Hiro VSThemes
    Comment=Multi-size xcursor pack from Windows .cur
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Nikaido Hiro cursor theme (VSThemes) as multi-size Xcursor";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
