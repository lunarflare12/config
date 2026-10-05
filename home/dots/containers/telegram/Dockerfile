FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        xz-utils \
        dbus \
        locales \
        libglib2.0-0 \
        libdbus-1-3 \
        libx11-6 \
        libx11-xcb1 \
        libxcb1 \
        libxcb-image0 \
        libxcb-keysyms1 \
        libxcb-randr0 \
        libxcb-render0 \
        libxcb-render-util0 \
        libxcb-shape0 \
        libxcb-shm0 \
        libxcb-sync1 \
        libxcb-xfixes0 \
        libxcb-xkb1 \
        libxcb-icccm4 \
        libxcb-util1 \
        libxkbcommon0 \
        libxkbcommon-x11-0 \
        libgl1 \
        libegl1 \
        libfontconfig1 \
        libfreetype6 \
        fonts-dejavu-core \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libgtk-3-0 \
        libglib2.0-0 \
        libxi6 \
        libxext6 \
        libxrender1 \
        libxss1 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxrandr2 \
        libasound2 \
        libpulse0 \
        libdrm2 \
        libnss3 \
        libxcb-cursor0 \
    && sed -i 's/^# \(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
    && sed -i 's/^# \(ru_RU.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

COPY td-setup.tar.xz /tmp/td-setup.tar.xz
RUN tar -xJf /tmp/td-setup.tar.xz -C /opt \
    && rm /tmp/td-setup.tar.xz \
    && if ! getent group 100 >/dev/null; then groupadd --gid 100 users; fi \
    && useradd --uid 1000 --gid 100 --create-home --shell /usr/sbin/nologin telegram \
    && chown -R 1000:100 /opt/Telegram

WORKDIR /home/telegram

ENV LANG=ru_RU.UTF-8 \
    LC_ALL=ru_RU.UTF-8 \
    QT_QPA_PLATFORM=xcb \
    QT_AUTO_SCREEN_SCALE_FACTOR=1

ENTRYPOINT ["/etc/profiles/per-user/dd/bin/aurora", "container", "telegram"]
