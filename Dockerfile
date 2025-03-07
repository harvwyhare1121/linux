#FROM ubuntu:jammy-20230425
FROM ubuntu:lunar-20230615

# Install the Cinnamon desktop environment
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y ubuntucinnamon-desktop locales sudo

# Install VNC and XRDP related packages
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y xrdp tigervnc-standalone-server && \
    adduser xrdp ssl-cert && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

# Define build-time variables for user credentials
ARG USER=testuser
ARG PASS=1234

# Create user, add to sudo group, and set bash as default shell
RUN useradd -m $USER -p $(openssl passwd $PASS) && \
    usermod -aG sudo $USER && \
    chsh -s /bin/bash $USER

# Create environment setup script for Cinnamon
RUN echo "#!/bin/sh\n\
export XDG_SESSION_DESKTOP=cinnamon\n\
export XDG_SESSION_TYPE=x11\n\
export XDG_CURRENT_DESKTOP=X-Cinnamon\n\
export XDG_CONFIG_DIRS=/etc/xdg/xdg-cinnamon:/etc/xdg" > /env && chmod 555 /env

# Create startup script for Cinnamon via DBus session
RUN echo "#!/bin/sh\n\
. /env\n\
exec dbus-run-session -- cinnamon-session" > /xstartup && chmod +x /xstartup

# Configure VNC for the created user
RUN mkdir /home/$USER/.vnc && \
    echo $PASS | vncpasswd -f > /home/$USER/.vnc/passwd && \
    chmod 0600 /home/$USER/.vnc/passwd && \
    chown -R $USER:$USER /home/$USER/.vnc

# Link the startup script for XRDP and VNC
RUN cp -f /xstartup /etc/xrdp/startwm.sh && \
    cp -f /xstartup /home/$USER/.vnc/xstartup

# Create a script to start the VNC server on port 5902
RUN echo "#!/bin/sh\n\
sudo -u $USER -g $USER -- vncserver -rfbport 5902 -geometry 1920x1080 -depth 24 -verbose -localhost no -autokill no" > /startvnc && chmod +x /startvnc

# Expose the XRDP and VNC ports
EXPOSE 3389
EXPOSE 5902

# Start necessary services and then the VNC server
CMD service dbus start; /usr/lib/systemd/systemd-logind & service xrdp start; /startvnc; bash
