# The default login program on CentOS doesn't work as expected under ttyd and systemd
# 
# The util-linux login program, unlike the shadow variation contains a small section
# of code that closes open file descriptors prior to opening the login binary.  This 
# unfortunately causes sporadic behaviour for ttyd/systemd
#
# The fix, detailed at https://lkml.org/lkml/2012/6/5/145 is for an issue that
# that hadn't been an issue for 20 years.  The patch, removes this section, therefore
# bringing back the original behaviour that is needed for this scenario
#
# Leverage the util-linux codebase, patch remove the fix and build a login binary in 
# a donor container that we will copy into /utils in our container
FROM quay.io/centos/centos:stream9 as loginbuild
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# Copy util-linux login.c patch
COPY login-c-patch /login-c-patch

RUN yum -y group install "Development Tools" \
    && yum -y install wget pam-devel \
    && cd /tmp \
    && wget https://github.com/karelzak/util-linux/archive/v2.36.tar.gz \
    && tar zxvf v2.36.tar.gz \
    && patch util-linux-2.36/login-utils/login.c < /login-c-patch \
    && cd util-linux-2.36 \
    && ./autogen.sh \
    && ./configure --enable-login \
    && make login

# Main Start
FROM spurin/container-systemd:centos_stream9

# Remove /etc/securetty, this is a lab instance, we're allowing root via ttyd by default
# Alter REMOVE_SECURETTY environment variable to disable
ENV REMOVE_SECURETTY="True"
RUN if [ "$REMOVE_SECURETTY" = "True" ]; then rm -rf /etc/securetty; fi

# Update and install openssh, sudo and dos2unix as well as hostname (needed for ttyd)
RUN yum install -y openssh-clients openssh-server sudo systemd systemd-udev dos2unix \
    hostname \
    && yum clean all

# Remove nologin (CentOS)
RUN rm -f /run/nologin

# Create required directories, Setup default login credentials
RUN mkdir -p /config \
    && echo root > /config/root_passwd \
    && echo guest > /config/guest_user \
    && echo guest > /config/guest_passwd \
    && echo '/bin/bash' > /config/guest_shell

# Required for CentOS, not for Ubuntu
RUN /usr/bin/ssh-keygen -A

## Setup ttyd, sources taken from https://github.com/tsl0922/ttyd/actions/runs/1667785057 as release has not been updated
# Source zip file - https://github.com/tsl0922/ttyd/suites/4862873475/artifacts/138479841
COPY ttyd.x86_64 /bin/ttyd.x86_64
# Source zip file - https://github.com/tsl0922/ttyd/suites/4862873475/artifacts/138479831
COPY ttyd.aarch64 /bin/ttyd.aarch64
# Symbolically link, according to the architecture of the build
RUN ln -s /bin/ttyd.$(uname -m) /bin/ttyd

# Startup services
COPY startup.service /lib/systemd/system/startup.service
COPY startup.sh /bin/startup.sh
# Capture the hostname (used for ttyd customisation)
COPY hostname_capture.service /lib/systemd/system/hostname_capture.service
# ttyd service
COPY ttyd.service /lib/systemd/system/ttyd.service

# Configure sshd for root access
RUN sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config

# Register startup, hostname_capture & ttyd service under multi-user.target.wants
RUN ln -s /lib/systemd/system/startup.service /etc/systemd/system/multi-user.target.wants/startup.service \
    && ln -s /lib/systemd/system/ttyd.service /etc/systemd/system/multi-user.target.wants/hostname_capture.service \
    && ln -s /lib/systemd/system/ttyd.service /etc/systemd/system/multi-user.target.wants/ttyd.service

# Copy login built from util-linux source code in multi stage build
COPY --from=loginbuild /tmp/util-linux-2.36/login /bin/login-patched

# Enable services
RUN systemctl enable startup hostname_capture ttyd sshd

# Open Ports
EXPOSE 22
EXPOSE 7681
