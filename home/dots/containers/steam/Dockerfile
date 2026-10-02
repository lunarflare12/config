FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Steam's Nix bwrap + Proton need a fuller userland than desktop-box.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus \
        locales \
        xz-utils \
        libasound2 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libatspi2.0-0 \
        libcairo2 \
        libcups2 \
        libdbus-1-3 \
        libdrm2 \
        libexpat1 \
        libgbm1 \
        libglib2.0-0 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libpango-1.0-0 \
        libpci3 \
        libpipewire-0.3-0 \
        libpulse0 \
        libva2 \
        libvulkan1 \
        libx11-6 \
        libx11-xcb1 \
        libxcb1 \
        libxcomposite1 \
        libxcursor1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxkbcommon0 \
        libxrandr2 \
        libxrender1 \
        libxss1 \
        libxtst6 \
        mesa-vulkan-drivers \
        zenity \
    && sed -i 's/^# \(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
    && sed -i 's/^# \(ru_RU.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/* \
    && if ! getent group 100 >/dev/null; then groupadd --gid 100 users; fi \
    && if ! getent group 989 >/dev/null; then groupadd --gid 989 steam; fi \
    && if ! getent group 992 >/dev/null; then groupadd --gid 992 gamemode; fi \
    && if ! getent group 174 >/dev/null; then groupadd --gid 174 input; fi \
    && if ! getent group 26 >/dev/null; then groupadd --gid 26 video; fi \
    && useradd --uid 1000 --gid 100 --create-home --shell /bin/bash \
         --groups steam,gamemode,input,video app

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

WORKDIR /home/dd
ENV LANG=ru_RU.UTF-8 \
    LC_ALL=ru_RU.UTF-8 \
    HOME=/home/dd \
    USER=dd \
    QT_QPA_PLATFORM=xcb \
    GDK_BACKEND=x11

RUN mkdir -p /home/dd && chown -R 1000:100 /home/dd

USER app
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
