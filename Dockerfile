FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages including Node.js dependencies
RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 xfce4-goodies \
    tightvncserver novnc websockify \
    sudo xterm vim net-tools curl wget \
    dbus-x11 x11-utils x11-xserver-utils \
    firefox \
    ca-certificates \
    gnupg

# Install Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install localtunnel globally
RUN npm install -g localtunnel

# Create user
RUN useradd -m -s /bin/bash ubuntu && \
    echo "ubuntu:ubuntu" | chpasswd && \
    adduser ubuntu sudo

# Setup VNC
RUN mkdir -p /root/.vnc && \
    echo "ubuntu" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup for VNC
RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'xrdb $HOME/.Xresources' >> /root/.vnc/xstartup && \
    echo 'startxfce4 &' >> /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Create startup script
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'set -e' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'echo "=== Starting Desktop Services ==="' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start VNC server' >> /start.sh && \
    echo 'echo "Starting VNC server..."' >> /start.sh && \
    echo 'vncserver :1 -geometry 1920x1080 -depth 24 || echo "VNC server may already be running"' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start noVNC' >> /start.sh && \
    echo 'echo "Starting noVNC on port 6080..."' >> /start.sh && \
    echo 'websockify -D --web=/usr/share/novnc/ 6080 localhost:5901' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Wait for services to stabilize' >> /start.sh && \
    echo 'sleep 5' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start localtunnel' >> /start.sh && \
    echo 'echo "=== Starting LocalTunnel ==="' >> /start.sh && \
    echo 'lt --port 6080 > /tmp/lt.log 2>&1 &' >> /start.sh && \
    echo 'LT_PID=$!' >> /start.sh && \
    echo 'echo "LocalTunnel PID: $LT_PID"' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Wait and retry to get the URL' >> /start.sh && \
    echo 'for i in {1..10}; do' >> /start.sh && \
    echo '    sleep 2' >> /start.sh && \
    echo '    if [ -f /tmp/lt.log ]; then' >> /start.sh && \
    echo '        LT_URL=$(grep -o "https://[a-z0-9-]*\\.loca\\.lt" /tmp/lt.log | head -1)' >> /start.sh && \
    echo '        if [ ! -z "$LT_URL" ]; then' >> /start.sh && \
    echo '            break' >> /start.sh && \
    echo '        fi' >> /start.sh && \
    echo '    fi' >> /start.sh && \
    echo '    echo "Waiting for LocalTunnel URL... (attempt $i/10)"' >> /start.sh && \
    echo 'done' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Display results' >> /start.sh && \
    echo 'echo ""' >> /start.sh && \
    echo 'echo "==============================================="' >> /start.sh && \
    echo 'echo "  UBUNTU DESKTOP WITH LOCALTUNNEL"' >> /start.sh && \
    echo 'echo "==============================================="' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'if [ ! -z "$LT_URL" ]; then' >> /start.sh && \
    echo '    echo "LocalTunnel URL: $LT_URL"' >> /start.sh && \
    echo '    echo ""' >> /start.sh && \
    echo '    echo "Fetching tunnel password..."' >> /start.sh && \
    echo '    TUNNEL_PASSWORD=$(curl -s https://loca.lt/mytunnelpassword || echo "Failed to fetch password")' >> /start.sh && \
    echo '    echo ""' >> /start.sh && \
    echo '    echo "Tunnel Password: $TUNNEL_PASSWORD"' >> /start.sh && \
    echo '    echo ""' >> /start.sh && \
    echo '    echo "==============================================="' >> /start.sh && \
    echo '    echo "  ACCESS YOUR DESKTOP:"' >> /start.sh && \
    echo '    echo "  URL: $LT_URL"' >> /start.sh && \
    echo '    echo "  Password: $TUNNEL_PASSWORD"' >> /start.sh && \
    echo '    echo "  VNC Password: ubuntu"' >> /start.sh && \
    echo '    echo "==============================================="' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '    echo "WARNING: Could not get LocalTunnel URL"' >> /start.sh && \
    echo '    echo "Check logs at: /tmp/lt.log"' >> /start.sh && \
    echo '    cat /tmp/lt.log' >> /start.sh && \
    echo '    echo "==============================================="' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'echo ""' >> /start.sh && \
    echo 'echo "Services are running. Container will stay alive."' >> /start.sh && \
    echo 'echo ""' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Keep container running and show logs' >> /start.sh && \
    echo 'tail -f /tmp/lt.log /dev/null' >> /start.sh && \
    chmod +x /start.sh

EXPOSE 6080 5901

CMD ["/start.sh"]
