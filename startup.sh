#!/bin/sh

# Run dos2unix against /config entries (fixes an issue where a config directory is cloned via git on windows)
# and carriage returns are converted to /r
if [ -f /config/guest_name ]; then
   echo "running command: dos2unix /config/guest_name"
   dos2unix /config/guest_name 2>&1
fi
if [ -f /config/guest_passwd ]; then
   echo "running command: dos2unix /config/guest_passwd"
   dos2unix /config/guest_passwd 2>&1
fi
if [ -f /config/guest_shell ]; then
   echo "running command: dos2unix /config/guest_shell"
   dos2unix /config/guest_shell 2>&1
fi
if [ -f /config/guest_ssh ]; then
   echo "running command: dos2unix /config/guest_ssh"
   dos2unix /config/guest_ssh 2>&1
fi
if [ -f /config/guest_ssh.pub ]; then
   echo "running command: dos2unix /config/guest_ssh.pub"
   dos2unix /config/guest_ssh.pub 2>&1
fi
if [ -f /config/root_passwd ]; then
   echo "running command: dos2unix /config/root_passwd"
   dos2unix /config/root_passwd 2>&1
fi
if [ -f /config/root_ssh ]; then
   echo "running command: dos2unix /config/root_ssh"
   dos2unix /config/root_ssh 2>&1
fi
if [ -f /config/root_ssh.pub ]; then
   echo "running command: dos2unix /config/root_ssh.pub"
   dos2unix /config/root_ssh.pub 2>&1
fi

# Guest Details
if [ -f /config/guest_name ]; then
   echo "capturing variable USER_NAME from /config/guest_name"
   USER_NAME=$(cat /config/guest_name)
else
   echo "setting default variable for USER_NAME"
   USER_NAME=guest
fi
if [ -f /config/guest_passwd ]; then
   echo "capturing variable USER_PASSWD from /config/guest_name"
   USER_PASSWD=$(cat /config/guest_passwd)
else
   echo "setting default variable for USER_PASSWD"
   USER_PASSWD=guest
fi
if
   [ -f /config/guest_shell ]
   echo "capturing variable USER_SHELL from /config/guest_name"
then USER_SHELL=$(cat /config/guest_shell); else
   echo "setting default variable for USER_SHELL"
   USER_SHELL='/bin/bash'
fi
USER_SSH_PRV=/config/guest_ssh
USER_SSH_PUB=/config/guest_ssh.pub

# Root Details
if [ -f /config/root_passwd ]; then
   echo "capturing variable ROOT_PASSWD from /config/root_passwd"
   ROOT_PASSWD=$(cat /config/root_passwd)
else
   "echo setting default variable for ROOT_PASSWD"
   ROOT_PASSWD=root
fi
ROOT_SSH_PRV=/config/root_ssh
ROOT_SSH_PUB=/config/root_ssh.pub

# If $USER_NAME doesn't exist, create specified user, set password and add to sudo group
echo "checking if user $USER_NAME exists"
if getent passwd $USER_NAME >/dev/null 2>&1; then
   echo "user $USER_NAME already exists"
else
   echo "user $USER_NAME does not exist"

   # If $USER_NAME isn't empty
   if [ -n "$USER_NAME" ]; then
      echo "running command: useradd -ms $USER_SHELL $USER_NAME"
      useradd -ms $USER_SHELL $USER_NAME
      echo "running command: usermod -aG sudo $USER_NAME"
      usermod -aG sudo $USER_NAME
   fi
fi

# Implicitly set the users home directory permissions
echo "running command: chown ${USER_NAME}:${USER_NAME} /home/${USER_NAME}"
chown ${USER_NAME}:${USER_NAME} /home/${USER_NAME}
echo "running command: chmod 755 /home/${USER_NAME}"
chmod 755 /home/${USER_NAME}

# If the /home/${USER_NAME} directory is empty, copy the /etc/skel files
if [ "$(ls -A /home/${USER_NAME})" ]; then
   echo "/home/${USER_NAME} exists and has data, ignoring"
else
   echo "/home/${USER_NAME} is empty, populating with /etc/skel"
   (
      cd /home/${USER_NAME}
      tar -cf - -C /etc/skel . | sudo -Hu "$USER_NAME" tar --skip-old-files -o -xf -
   )
fi

# Set $USER_NAME password
echo "setting user $USER_NAME password"
echo "$USER_NAME:$USER_PASSWD" | chpasswd

# Configure ${USER_NAME} SSH keys
if [ -f "$USER_SSH_PUB" ] && [ -f "$USER_SSH_PRV" ]; then
   echo "/config contains guest ssh public and private key, configuring ssh"
   mkdir -p /home/${USER_NAME}/.ssh
   chown $USER_NAME:$USER_NAME /home/${USER_NAME}/.ssh
   cat $USER_SSH_PRV >/home/${USER_NAME}/.ssh/id_rsa
   cat $USER_SSH_PUB >/home/${USER_NAME}/.ssh/id_rsa.pub
   if [ -z "$(grep \"$(cat $USER_SSH_PUB)\" /home/${USER_NAME}/.ssh/authorized_keys)" ]; then
      cat $USER_SSH_PUB >>/home/${USER_NAME}/.ssh/authorized_keys
      echo SSH key added to authorized keys
   fi
   chown $USER_NAME:$USER_NAME /home/${USER_NAME}/.ssh/id_rsa
   chown $USER_NAME:$USER_NAME /home/${USER_NAME}/.ssh/id_rsa.pub
   chown $USER_NAME:$USER_NAME /home/${USER_NAME}/.ssh
   chmod 600 /home/${USER_NAME}/.ssh/id_rsa
   chmod 600 /home/${USER_NAME}/.ssh/id_rsa.pub
   chmod 644 /home/${USER_NAME}/.ssh/id_rsa.pub
   chmod 700 /home/${USER_NAME}/.ssh
fi

# Set $ROOT_NAME password
echo "setting root password"
echo "root:$ROOT_PASSWD" | chpasswd

# Set default permissions for /root
echo "running command: chown root:root /root"
chown root:root /root
echo "running command: chmod 700 /root"
chmod 700 /root

# Configure root SSH keys
if [ -f "$ROOT_SSH_PUB" ] && [ -f "$ROOT_SSH_PRV" ]; then
   echo "/config contains root ssh public and private key, configuring ssh"
   mkdir -p /root/.ssh
   cat $ROOT_SSH_PRV >/root/.ssh/id_rsa
   cat $ROOT_SSH_PUB >/root/.ssh/id_rsa.pub
   if [ -z "$(grep \"$(cat $ROOT_SSH_PUB)\" /root/.ssh/authorized_keys)" ]; then
      cat $ROOT_SSH_PUB >>/root/.ssh/authorized_keys
      echo SSH key added added to authorized_keys
   fi
   chmod 600 /root/.ssh/id_rsa
   chmod 600 /root/.ssh/id_rsa.pub
   chmod 644 /root/.ssh/authorized_keys
   chmod 700 /root/.ssh
fi

# Remove nologin
if [ -f /run/nologin ]; then
   echo "running command: rm -rf /run/nologin"
   rm -rf /run/nologin 2>&1
fi
