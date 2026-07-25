#!/usr/bin/env bash
set -eu

PATH_TO_ROOT=".."
ROOT_DIR="$(cd `dirname $0`;pwd)/${PATH_TO_ROOT}"
CURRENT_USER=`whoami`

echo "#### Setup Ansible ####"
# 存在確認ではなく実行可否で判定する。pip で入れた古い ansible が
# 新しい Python で ImportError になり、PATH 上で apt 版を隠すことがある
if ! ansible --version > /dev/null 2>&1; then
	if type ansible > /dev/null 2>&1; then
		echo "ERROR: $(command -v ansible) が実行できません。削除してから再実行してください" >&2
		echo "  python3 -m pip uninstall ansible" >&2
		exit 1
	fi
	sudo apt-get update
	sudo apt-get install -y ansible
else
	echo "Ansible is already installed";
fi
ansible --version

echo "#### Exec Ansible ####"
cd ${ROOT_DIR}/ansible
CMD="ansible-playbook -i ./hosts/local --extra-vars ansible_exec_user=${CURRENT_USER} --extra-vars ansible_exec_user_home=${HOME} ./site.yml ${@}"
echo "command: ${CMD}"
command ${CMD}
