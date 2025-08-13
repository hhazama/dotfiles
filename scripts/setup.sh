#!/usr/bin/env bash
set -eu

PATH_TO_ROOT=".."
ROOT_DIR="$(cd `dirname $0`;pwd)/${PATH_TO_ROOT}"
CURRENT_USER=`whoami`

echo "#### Setup Ansible ####"
if type ansible > /dev/null 2>&1; then
	echo "Ansible is already installed";
else
	sudo apt-get update
	sudo apt-get install -y ansible
fi
ansible --version

echo "#### Exec Ansible ####"
cd ${ROOT_DIR}/ansible
CMD="ansible-playbook -i ./hosts/local --extra-vars ansible_exec_user=${CURRENT_USER} --extra-vars ansible_exec_user_home=${HOME} ./site.yml ${@}"
echo "command: ${CMD}"
command ${CMD}
