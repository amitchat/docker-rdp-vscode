# Creates a Docker Container with Visual Studio Code and RDP Support.
#
# Also configures the following:
# - XRDP with Drive Redirection + Clipboard support
# - XFCE window manager
# - Better Font Rendering with Infinality
# - Fix Tab keyboard mapping.
# - Numix Theme for XFCE
# - Default User Account

FROM ubuntu
MAINTAINER Amit Chattopadhyay <amitchat@gmail.com>

# Setup Configurable Environment 
ENV USERNAME vscode
ENV PASSWORD vscode

# Install Packages
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common \
 && add-apt-repository ppa:hermlnx/xrdp -y \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install \
    xfce4 \
    ubuntu-desktop \
    xubuntu-desktop \
    git \
    libx11-dev \
    libxfixes-dev \
    libssl-dev \
    libpam0g-dev \
    libtool \
    libjpeg-dev \
    flex \
    bison \
    gettext \
    autoconf \
    libxml-parser-perl \
    libfuse-dev \
    xsltproc \
    libxrandr-dev \
    python-libxml2 \
    nasm \
    xserver-xorg-dev \
    fuse \
    xrdp \
    vim \
    supervisor

# Build XRDP from Sources
WORKDIR /
RUN git clone https://github.com/neutrinolabs/xrdp.git \
 && cd xrdp/ \
 && git clone https://github.com/neutrinolabs/xorgxrdp.git \
 && cd xorgxrdp \
 && ./bootstrap \
 && ./configure \
 && make \
 && make install \
 && cd .. \
 && DEBIAN_FRONTEND=noninteractive apt-get -y remove xrdp \
 && cd /xrdp \
 && sed -i.bak 's/which libtool/which libtoolize/g' bootstrap \
 && ./bootstrap \
 && ./configure --enable-fuse --enable-jpeg \
 && make \
 && make install

# Setup XRDP
RUN sed -i.bak '/\[xrdp1\]/i [xrdp0] \nname=Default \nlib=libxup.so \nusername=ask \npassword=ask \nip=127.0.0.1 \nport=-1 \nxserverbpp=24 \ncode=20 \n' /etc/xrdp/xrdp.ini \
 && sed -i.bak 's/max_bpp=32/max_bpp=24 use_compression=yes/' /etc/xrdp/xrdp.ini \
 && sed -i.bak 's/autorun=xrdp1/autorun=xrdp0/' /etc/xrdp/xrdp.ini \
 && sed -i.bak 's/rdpsnd=true/rdpsnd=false/' /etc/xrdp/xrdp.ini \
 && rm -f /etc/xrdp/startwm.sh \
 && ln -s /etc/X11/Xsession /etc/xrdp/startwm.sh \
 && mkdir /usr/share/doc/xrdp \
 && cp /etc/xrdp/rsakeys.ini /usr/share/doc/xrdp/rsakeys.ini \
 && sed -i.bak 's/EnvironmentFile/#EnvironmentFile/g' /lib/systemd/system/xrdp.service \
 && sed -i.bak 's/sbin\/xrdp/local\/sbin\/xrdp/g' /lib/systemd/system/xrdp.service \
 && sed -i.bak 's/EnvironmentFile/#EnvironmentFile/g' /lib/systemd/system/xrdp-sesman.service \
 && sed -i.bak 's/sbin\/xrdp/local\/sbin\/xrdp/g' /lib/systemd/system/xrdp-sesman.service \
 && ln -s /usr/local/sbin/xrdp /usr/sbin/xrdp \
 && ln -s /usr/local/sbin/xrdp-sesman /usr/sbin/xrdp-sesman \
 && systemctl enable xrdp.service \
 && sed -i.bak '/set -e/a xfce4-session' /etc/xrdp/startwm.sh \
 && sed -i -e 's/<property name="\&lt;Super\&gt;Tab" type="string" value="switch_window_key"\/>/<property name="\&lt;Super\&gt;Tab" type="empty"\/>/' \
             /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml \
 && sed -i -e 's/<property name="ThemeName" type="string" value="Greybird"\/>/<property name="ThemeName" type="string" value="Numix"\/>/' \
             /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
 && mkdir /etc/xdg/xfce4/terminal \
 && mkdir /etc/xdg/xfce4/xfconf/xfce-prechannel-xml \
 && mv /etc/xdg/xfce4/panel/default.xml /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml \
 && rm -f /etc/xdg/autostart/blueman.desktop

# Install Infinality for Better Font
RUN apt-add-repository ppa:no1wantdthisname/ppa \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    fontconfig-infinality \
 && bash /etc/fonts/infinality/infctl.sh setstyle osx

# Create User Account
RUN useradd --create-home --shell /bin/bash --user-group --groups adm,sudo $USERNAME \
 && echo "$USERNAME:$PASSWORD" | chpasswd

# Configure User Account
RUN echo "xfce4-session" > /home/$USERNAME/.xsession \
 && chmod u+x /home/$USERNAME/.xsession \
 && mkdir /home/$USERNAME/.config/xfce4 \
 && mkdir /home/$USERNAME/.config/xfce4/terminal

# Install VSCode
RUN wget https://go.microsoft.com/fwlink/?LinkID=760868 -O code.deb \
 && dpkg -i code.deb \
 && sed -i 's/BIG-REQUESTS/_IG-REQUESTS/' /usr/lib/x86_64-linux-gnu/libxcb.so.1 \
 && rm -f code.deb \
 && mv /usr/bin/gnome-terminal /usr/bin/gnome-terminal-old

# Copy Files
COPY terminalrc /home/$USERNAME/.config/xfce4/terminal/terminalrc
COPY ms-loves-linux.jpg /usr/share/backgrounds/xfce/xfce-teal.jpg
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

# Ensure home ownership by $USERNAME
RUN chown -R $USERNAME /home/$USERNAME

# Expose RDP Port
EXPOSE 3389

# Kick off supervisor to start the RDP server.
ENTRYPOINT ["/entrypoint.sh"]
