FROM jenkins/slave
MAINTAINER Adrian Bienkowski

# -- copy start up script
COPY jenkins-slave /usr/local/bin/jenkins-slave

# -- switch to root user for tool configuration
USER root

# -- make sure script has executable permissions
RUN chmod +x /usr/local/bin/jenkins-slave

# -- install build essentials and tools
RUN apt update -qqy \
 && apt upgrade -qqy \
 && apt -qqy install \
    build-essential \
    ca-certificates \
    clang \
    curl \
    git \
    jq \
    less \
    libxml2-utils \
    openssh-client \
    openssl \
    python \
    rsync \
    tzdata \
    unzip \
    make\
    automake \
    autoconf \
    gcc g++ \
    openjdk-8-jdk \
    ruby \
    wget \
    curl \
    xmlstarlet \
    openbox \
    xterm \
    net-tools \
    ruby-dev \
    python-pip \
    xvfb \
    x11vnc \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN gem install zapr
RUN pip install --upgrade pip zapcli python-owasp-zap-v2.4

# -- Install security tools in TOOLS_DIR
ENV SPOTBUGS_VERSION=3.1.11
ENV DEPCHECK_VERSION=4.0.2
ENV ZAP_VERSION=2.7.0
ENV ZAP_VERSION_F=2_7_0
ENV TOOLS_DIR=/opt/security-tools
ENV DEPCHECK_DATA=$TOOLS_DIR/dependency-check/data
 
RUN mkdir -p $TOOLS_DIR

# -- Install SpotBugs with FindSecBugs plugin
RUN curl -sSL http://central.maven.org/maven2/com/github/spotbugs/spotbugs/${SPOTBUGS_VERSION}/spotbugs-${SPOTBUGS_VERSION}.tgz | tar -zxf - -C $TOOLS_DIR \
 && curl --create-dirs -sSLo /opt/security-tools/spotbugs-${SPOTBUGS_VERSION}/plugin/findsecbugs-plugin.jar http://central.maven.org/maven2/com/h3xstream/findsecbugs/findsecbugs-plugin/1.8.0/findsecbugs-plugin-1.8.0.jar
 
# -- Install OWASP Depdendency check
RUN cd $TOOLS_DIR \
 && curl -sSLO https://dl.bintray.com/jeremy-long/owasp/dependency-check-${DEPCHECK_VERSION}-release.zip \
 && unzip dependency-check-${DEPCHECK_VERSION}-release.zip \
 && rm -f dependency-check-${DEPCHECK_VERSION}-release.zip
 
# -- make data directory to persist downloads
RUN mkdir -p $DEPCHECK_DATA \
 && chown jenkins:jenkins $DEPCHECK_DATA

# --Install OWASP ZAP
#Download all ZAP docker files
RUN git clone https://github.com/zaproxy/zaproxy.git

#Switch to the docker folder
WORKDIR zaproxy/docker

RUN gem install zapr
RUN pip install --upgrade pip zapcli python-owasp-zap-v2.4 

RUN useradd -d /home/zap -m -s /bin/bash zap
RUN echo zap:zap | chpasswd
RUN mkdir /zap && chown zap:zap /zap

#Change to the zap user so things get done as the right person (apart from copy)
USER zap

RUN mkdir /home/zap/.vnc

# Download and expand the latest stable release for ZAP
RUN curl -s https://raw.githubusercontent.com/zaproxy/zap-admin/master/ZapVersions.xml | xmlstarlet sel -t -v //url |grep -i Linux | wget -nv --content-disposition -i - -O - | tar zxv
RUN cp -R ZAP*/* . 
RUN rm -R ZAP* 
# Setup Webswing
RUN curl -s -L https://bitbucket.org/meszarv/webswing/downloads/webswing-2.5.10.zip > webswing.zip
RUN unzip webswing.zip
RUN rm webswing.zip
RUN mv webswing-* webswing
# Remove Webswing demos
RUN rm -R webswing/demo/
# Accept ZAP license
RUN touch AcceptedLicense


ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
ENV PATH $JAVA_HOME/bin:/zap/:$PATH
ENV ZAP_PATH /zap/zap.sh

# Default port for use with zapcli
ENV ZAP_PORT 8080
ENV HOME /home/zap/

RUN pwd
RUN ls -la

COPY zap* /zap/
COPY webswing.config /zap/webswing/
COPY policies /home/zap/.ZAP/policies/
COPY .xinitrc /home/zap/

#Copy doesn't respect USER directives so we need to chown and to do that we need to be root
USER root

RUN chown zap:zap /zap/zap-x.sh && \
	chown zap:zap /zap/zap-baseline.py && \
	chown zap:zap /zap/zap-webswing.sh && \
	chown zap:zap /zap/webswing/webswing.config && \
	chown zap:zap -R /home/zap/.ZAP/ && \
	chown zap:zap /home/zap/.xinitrc && \
	chmod a+x /home/zap/.xinitrc

#Change back to zap at the end
USER zap

HEALTHCHECK --retries=5 --interval=5s CMD zap-cli status


# -- as jenkins user
USER jenkins

# -- set entrypoint for the container
ENTRYPOINT ["/usr/local/bin/jenkins-slave"]
