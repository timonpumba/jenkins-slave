FROM jenkins/slave
MAINTAINER Adrian Bienkowski

# -- copy start up script
COPY jenkins-slave /usr/local/bin/jenkins-slave

# -- switch to root user for tool configuration
USER root

# -- make sure script has executable permissions
RUN chmod +wx /usr/local/bin/jenkins-slave

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
    vim \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

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
RUN mkdir -p $TOOLS_DIR/zaproxy
RUN mkdir -p $TOOLS_DIR/webswing
RUN git clone https://github.com/zaproxy/zaproxy.git $TOOLS_DIR/zaproxy

RUN gem install zapr
RUN pip install --upgrade pip zapcli python-owasp-zap-v2.4 

#RUN useradd -d /home/zap -m -s /bin/bash zap
#RUN echo zap:zap | chpasswd
RUN mkdir $TOOLS_DIR/zap && chown jenkins:jenkins $TOOLS_DIR/zap
RUN mkdir $TOOLS_DIR/zap/webswing && chown jenkins:jenkins $TOOLS_DIR/zap/webswing

RUN curl -s https://raw.githubusercontent.com/zaproxy/zap-admin/master/ZapVersions.xml | xmlstarlet sel -t -v //url |grep -i Linux | wget -nv --content-disposition -i - -O - | tar zxv -C $TOOLS_DIR/zaproxy \
    && cp -R $TOOLS_DIR/zaproxy/ZAP*/* $TOOLS_DIR/zap/ \
    && rm -R $TOOLS_DIR/zaproxy/ZAP* \
    && curl -s -L https://bitbucket.org/meszarv/webswing/downloads/webswing-2.5.10.zip > $TOOLS_DIR/webswing.zip \
    # Setup Webswing
    && unzip $TOOLS_DIR/webswing.zip -d $TOOLS_DIR/webswing \
    && mv $TOOLS_DIR/webswing/webswing-* $TOOLS_DIR/zap/webswing \
    && rm $TOOLS_DIR/webswing.zip \
    && rm -R $TOOLS_DIR/webswing/* \
    # Remove Webswing demos
    && rm -R $TOOLS_DIR/zap/webswing/demo/ \
    # Accept ZAP license
    && touch AcceptedLicense


RUN cd $TOOLS_DIR && ls -la

RUN mkdir $TOOLS_DIR/zap/.vnc

ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
ENV PATH $JAVA_HOME/bin:$TOOLS_DIR/zap/:$PATH
ENV ZAP_PATH $TOOLS_DIR/zap/zap.sh

# Default port for use with zapcli
ENV ZAP_PORT 8080
ENV HOME /home/jenkins/

RUN cp $TOOLS_DIR/zaproxy/docker/zap* $TOOLS_DIR/zaproxy/ \
 && cp $TOOLS_DIR/zaproxy/docker/webswing.config  $TOOLS_DIR/zap/webswing/ \
 && mkdir -p /home/jenkins/.ZAP/policies/ \
 && cp -r $TOOLS_DIR/zaproxy/docker/policies /home/jenkins/.ZAP/policies/ \
 && cp $TOOLS_DIR/zaproxy/docker/.xinitrc /home/jenkins/

RUN chown jenkins:jenkins zap-x.sh && \
	chown jenkins:jenkins zap-baseline.py && \
	chown jenkins:jenkins zap-webswing.sh && \
	chown jenkins:jenkins webswing/webswing.config && \
	chown jenkins:jenkins -R $TOOLS_DIR/.ZAP/ && \
	chown jenkins:jenkins /home/jenkins/.xinitrc && \
	chmod a+x /home/jenkins/.xinitrc

HEALTHCHECK --retries=5 --interval=5s CMD zap-cli status


# -- as jenkins user
USER jenkins

# -- set entrypoint for the container
ENTRYPOINT ["/usr/local/bin/jenkins-slave"]
