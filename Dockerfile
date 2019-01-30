FROM openjdk:8u181-jdk-slim-stretch

EXPOSE 8080 8000 5900

ENV TERM xterm \
    DISP_SIZE 1600x900x16

RUN apt-get update && apt-get install -y --no-install-recommends apt-utils dialog wget unzip mc curl sudo && \
    echo "%sudo ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    useradd -u 1000 -G users,sudo -d /home/user --shell /bin/bash -m user && \
    echo "secret\nsecret" | passwd user && \
    apt-get -qqy install supervisor x11vnc xvfb subversion net-tools blackbox rxvt-unicode xfonts-terminus dbus-x11 python-numpy
    
#USER user

# download and install noVNC, Firefox, Eclipse CDT, configure Blackbox
RUN sudo mkdir -p /opt/noVNC/utils/websockify && \
    wget -qO- "http://github.com/kanaka/noVNC/tarball/master" | sudo tar -zx --strip-components=1 -C /opt/noVNC && \
    wget -qO- "https://github.com/kanaka/websockify/tarball/master" | sudo tar -zx --strip-components=1 -C /opt/noVNC/utils/websockify && \
    sudo mkdir -p /etc/X11/blackbox && \
    echo "[begin] (Blackbox) \n \
    [exec] (Terminal)    {urxvt -fn "xft:Terminus:size=14"} \n \
    [exec] (Firefox)     {firefox} \n \
    [exec] (Eclipse CDT) {/opt/eclipse/eclipse} \n \
    [end]" | sudo tee -a /etc/X11/blackbox/blackbox-menu && \
    sudo mkdir -p /home/user/KeepAlive

ADD index.html  /opt/noVNC/
ADD supervisord.conf /opt/
ADD keepalive.html /home/user/KeepAlive

EXPOSE 6080 32745

ENV DISPLAY :20.0
ENV MAVEN_VERSION=3.3.9 \
    TOMCAT_HOME=/home/user/tomcat8
ENV M2_HOME=/home/user/apache-maven-$MAVEN_VERSION
ENV PATH=$M2_HOME/bin:$PATH

RUN mkdir /home/user/cbuild /home/user/tomcat8 /home/user/apache-maven-$MAVEN_VERSION
RUN sudo wget -qO- "http://apache.ip-connect.vn.ua/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz" | tar -zx --strip-components=1 -C /home/user/apache-maven-$MAVEN_VERSION/
RUN sudo wget -qO- "http://archive.apache.org/dist/tomcat/tomcat-8/v8.0.24/bin/apache-tomcat-8.0.24.tar.gz" | sudo tar -zx --strip-components=1 -C /home/user/tomcat8 && \
    sudo rm -rf /home/user/tomcat8/webapps/*
RUN sudo mkdir -p /etc/pki/tls/cert
RUN sudo openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/pki/tls/certs/novnc.pem -out /etc/pki/tls/certs/novnc.pem -days 3650 \
         -subj "/C=PH/ST=Cebu/L=Cebu/O=NA/OU=NA/CN=codenvy.io"
RUN sudo chmod 444 /etc/pki/tls/certs/novnc.pem
#Then later update /opt/supervisord.conf last line to read -> command=/opt/noVNC/utils/launch.sh --cert /etc/pki/tls/certs/novnc.pem --ssl-only

RUN echo "export M2_HOME=/home/user/apache-maven-$MAVEN_VERSION\n\
    export TOMCAT_HOME=/home/user/tomcat8\n\
    export PATH=$JAVA_HOME/bin:$M2_HOME/bin:$PATH\n\
    if [ ! -f /projects/KeepAlive/keepalive.html ]\nthen\nsleep 5\ncp -rf /home/user/KeepAlive /projects\nfi\n\
    sudo date >> /home/user/date.log" | sudo tee -a /home/user/.bashrc

# Thanks to zmart/eclipse-cdt for ideas on unattended CDT install
#USER root
ENV USER_NAME=user \
    HOME=/home/${USER_NAME}

ARG ECLIPSE_MIRROR=http://ftp.fau.de/eclipse/technology/epp/downloads/release/photon/R
ARG ECLIPSE_TAR=eclipse-cpp-photon-R-linux-gtk-x86_64.tar.gz

RUN apt-get install -y g++ build-essential gdb cmake && \
    wget ${ECLIPSE_MIRROR}/${ECLIPSE_TAR} -O /tmp/eclipse.tar.gz -q && tar -xf /tmp/eclipse.tar.gz -C /opt && rm /tmp/eclipse.tar.gz && \
    sudo sed "s/@user.home/\/projects/g" -i /opt/eclipse/eclipse.ini

USER user

WORKDIR /projects

ENV ECLIPSE_WORKSPACE=/projects/eclipse-workspace \
    ECLIPSE_DOT=/projects/.eclipse \
    DELAY=50

CMD /usr/bin/supervisord -c /opt/supervisord.conf -l /home/user/supervisor.log -e trace & sleep 365d
