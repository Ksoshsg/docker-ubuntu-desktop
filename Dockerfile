FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 xfce4-goodies \
    tightvncserver novnc websockify \
    sudo xterm init systemd snapd vim net-tools curl wget

# Install X11 and utilities
RUN apt update -y && apt install -y dbus-x11 x11-utils x11-xserver-utils

# Install additional software
RUN apt install software-properties-common -y

# Add Firefox repository and install
RUN add-apt-repository ppa:mozillateam/ppa -y
RUN echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' | tee /apt.conf.d/51unattended-upgrades-firefox
RUN apt update -y && apt install -y firefox

# Install theme
RUN apt update -y && apt install -y xubuntu-icon-theme

# Install Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install localtunnel globally
RUN npm install -g localtunnel

# Create user
RUN useradd -m -s /bin/bash ubuntu && echo "ubuntu:ubuntu" | chpasswd && adduser ubuntu sudo

# Setup VNC
RUN mkdir -p /root/.vnc
RUN echo "ubuntu" | vncpasswd -f > /root/.vnc/passwd
RUN chmod 600 /root/.vnc/passwd

# Create xstartup for VNC
RUN echo '#!/bin/bash\n\
xrdb $HOME/.Xresources\n\
startxfce4 &' > /root/.vnc/xstartup && \
chmod +x /root/.vnc/xstartup

# Create startup script with better error handling
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "=== Starting Desktop Services ==="\n\
\n\
# Start VNC server\n\
echo "Starting VNC server..."\n\
vncserver :1 -geometry 1920x1080 -depth 24 || echo "VNC server may already be running"\n\
\n\
# Start noVNC\n\
echo "Starting noVNC on port 6080..."\n\
websockify -D --web=/usr/share/novnc/ 6080 localhost:5901\n\
\n\
# Wait for services to stabilize\n\
sleep 5\n\
\n\
# Start localtunnel\n\
echo "=== Starting LocalTunnel ==="\n\
lt --port 6080 > /tmp/lt.log 2>&1 &\n\
LT_PID=$!\n\
echo "LocalTunnel PID: $LT_PID"\n\
\n\
# Wait and retry to get the URL\n\
for i in {1..10}; do\n\
    sleep 2\n\
    if [ -f /tmp/lt.log ]; then\n\
        LT_URL=$(grep -o "https://[a-z0-9-]*\\.loca\\.lt" /tmp/lt.log | head -1)\n\
        if [ ! -z "$LT_URL" ]; then\n\
            break\n\
        fi\n\
    fi\n\
    echo "Waiting for LocalTunnel URL... (attempt $i/10)"\n\
done\n\
\n\
# Display results\n\
echo ""\n\
echo "==============================================="\n\
echo "  UBUNTU DESKTOP WITH LOCALTUNNEL"\n\
echo "==============================================="\n\
\n\
if [ ! -z "$LT_URL" ]; then\n\
    echo "LocalTunnel URL: $LT_URL"\n\
    echo ""\n\
    echo "Fetching tunnel password..."\n\
    TUNNEL_PASSWORD=$(curl -s https://loca.lt/mytunnelpassword || echo "Failed to fetch password")\n\
    echo ""\n\
    echo "Tunnel Password: $TUNNEL_PASSWORD"\n\
    echo ""\n\
    echo "==============================================="\n\
    echo "  ACCESS YOUR DESKTOP:"\n\
    echo "  URL: $LT_URL"\n\
    echo "  Password: $TUNNEL_PASSWORD"\n\
    echo "  VNC Password: ubuntu"\n\
    echo "==============================================="\n\
else\n\
    echo "WARNING: Could not get LocalTunnel URL"\n\
    echo "Check logs at: /tmp/lt.log"\n\
    cat /tmp/lt.log\n\
    echo "==============================================="\n\
fi\n\
\n\
echo ""\n\
echo "Services are running. Container will stay alive."\n\
echo ""\n\
\n\
# Keep container running and show logs\n\
tail -f /tmp/lt.log /dev/null' > /start.sh && \
chmod +x /start.sh

EXPOSE 6080 5901

CMD ["/start.sh"]
