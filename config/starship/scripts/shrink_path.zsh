#!/usr/bin/env zsh

local split repo_path dir=${PWD/#~\//\~/}
case $dir in
	~) dir='~' ;;
	*) 
		repo_root=$(git rev-parse --show-toplevel 2> /dev/null)
		if [ -n "$repo_root" ]; then
			repo_path=${dir/#$repo_root/}
			dir=$repo_root
		fi
		split=( "${(@s:/:)dir}" )
		dir=${(j:/:M)split#?}${split[-1]:1}${repo_path:""} ;;
esac
echo $dir