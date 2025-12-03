FROM ubuntu:22.04

# Install base packages
RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 xfce4-goodies \
    tightvncserver novnc websockify \
    sudo xterm init systemd snapd vim net-tools curl

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

# Create user
RUN useradd -m -s /bin/bash ubuntu && echo "ubuntu:ubuntu" | chpasswd && adduser ubuntu sudo

# Install Node.js and localtunnel
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
RUN apt install -y nodejs
RUN npm install -g localtunnel

# Setup VNC
RUN mkdir -p /root/.vnc
RUN echo "ubuntu" | vncpasswd -f > /root/.vnc/passwd
RUN chmod 600 /root/.vnc/passwd

# Create startup script
RUN echo '#!/bin/bash\n\
# Start VNC server\n\
vncserver :1 -geometry 1920x1080 -depth 24\n\
\n\
# Start noVNC\n\
websockify -D --web=/usr/share/novnc/ 6080 localhost:5901\n\
\n\
# Wait for services to start\n\
sleep 3\n\
\n\
# Start localtunnel and capture URL\n\
echo "Starting localtunnel for port 6080..."\n\
lt --port 6080 > /tmp/lt.log 2>&1 &\n\
LT_PID=$!\n\
\n\
# Wait for localtunnel to generate URL\n\
sleep 5\n\
\n\
# Extract and display the URL\n\
LT_URL=$(grep -o "https://[a-z0-9-]*\.loca\.lt" /tmp/lt.log | head -1)\n\
echo "==============================================="\n\
echo "LocalTunnel URL: $LT_URL"\n\
echo "==============================================="\n\
\n\
# Get the tunnel password\n\
if [ ! -z "$LT_URL" ]; then\n\
    echo "Fetching tunnel password..."\n\
    TUNNEL_PASSWORD=$(curl -s https://loca.lt/mytunnelpassword)\n\
    echo "==============================================="\n\
    echo "Tunnel Password: $TUNNEL_PASSWORD"\n\
    echo "==============================================="\n\
    echo ""\n\
    echo "Access your desktop at: $LT_URL"\n\
    echo "Use password: $TUNNEL_PASSWORD"\n\
    echo "==============================================="\n\
fi\n\
\n\
# Keep container running\n\
tail -f /dev/null' > /start.sh

RUN chmod +x /start.sh

EXPOSE 6080

CMD ["/start.sh"]
