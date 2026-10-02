FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        dbus \
        locales \
        libgtk-3-0 \
        libnss3 \
        libgbm1 \
        libasound2 \
    && sed -i 's/^# \(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
    && sed -i 's/^# \(ru_RU.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/* \
    && if ! getent group 100 >/dev/null; then groupadd --gid 100 users; fi \
    && useradd --uid 1000 --gid 100 --create-home --shell /usr/sbin/nologin app

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

WORKDIR /home/app
ENV LANG=ru_RU.UTF-8 \
    LC_ALL=ru_RU.UTF-8 \
    HOME=/home/app \
    QT_QPA_PLATFORM=wayland \
    GDK_BACKEND=wayland \
    MOZ_ENABLE_WAYLAND=1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
