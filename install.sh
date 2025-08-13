#!/usr/bin/env bash
set -eu

GIT_USER="hhazama"
SSH_KEY_PATH=${HOME}/.ssh/id_ed25519_${GIT_USER}
SSH_AUTHORIZED_KEYS=${HOME}/.ssh/authorized_keys]


if [[ ! -e ${SSH_KEY_PATH} ]]; then
	echo "#### Create SSH Key ####"
	ssh-keygen -t ed25519 -f ${SSH_KEY_PATH}
fi

if [[ ! -e ${SSH_AUTHORIZED_KEYS} ]]; then
	touch ${SSH_AUTHORIZED_KEYS}
fi
(cat ${SSH_AUTHORIZED_KEYS} | grep "$(cat ${SSH_KEY_PATH}.pub)") ||
	(
		echo "#### Add local pub key to ${SSH_AUTHORIZED_KEYS} ####" &&
		(cat ${SSH_KEY_PATH}.pub >> ${SSH_AUTHORIZED_KEYS})
	)

echo "SSH pub key is: $(cat ${SSH_KEY_PATH}.pub)"

GIT_HOST="github.com"
echo "Have you registered your SSH key with ${GIT_HOST}?"
read -p "If not, please do so and press enter: "

echo "#### Make sure you can connect to ${GIT_HOST} ####"
ssh -T git@${GIT_HOST} || true

DATA_DIR=${DATA_DIR:-"/data"}
sudo mkdir -p -m 777 /data

echo "#### Clone dotfiles repository ####"
INSTALL_DIR=${DATA_DIR}/repos/${GIT_USER}/dotfiles
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating dotfiles..."
    git -C "$INSTALL_DIR" pull
else
    echo "Installing dotfiles..."
    git clone git@${GIT_HOST}:${GIT_USER}/dotfiles.git "$INSTALL_DIR"
fi

bash "$INSTALL_DIR/scripts/setup.sh"

