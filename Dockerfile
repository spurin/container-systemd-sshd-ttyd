FROM spurin/container-systemd:ubuntu_22.04

# Remove /etc/securetty, this is a lab instance, we're allowing root via ttyd by default
# Alter REMOVE_SECURETTY environment variable to disable
ENV REMOVE_SECURETTY="True"
RUN if [ "$REMOVE_SECURETTY" = "True" ]; then rm -rf /etc/securetty; fi

# Update and install locales, openssh-server, sudo and dos2unix
RUN apt-get update \
    && apt-get install -y locales openssh-server sudo dos2unix \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create required directories, Setup default login credentials
RUN mkdir -p /config \
    && echo root > /config/root_passwd \
    && echo guest > /config/guest_user \
    && echo guest > /config/guest_passwd \
    && echo '/bin/bash' > /config/guest_shell

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

# Enable services
RUN systemctl enable startup hostname_capture ttyd ssh

# Open Ports
EXPOSE 22
EXPOSE 7681
