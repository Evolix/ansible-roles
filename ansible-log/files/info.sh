#!/bin/sh

ppid=$(ps -p "$$" -o ppid=)
pppid=$(ps -p "$ppid" -o ppid=)
ppppid=$(ps -p "$pppid" -o ppid=)

ps --pid "$ppppid" -o command=
echo ""

git config --get remote.origin.url
git log --pretty="%h - %s" -3

ansible_cfg=$(ansible --version|grep "config file"|awk -F'=' '{print $2}'|xargs)
roles_path=$(grep "roles_path" $ansible_cfg|awk -F'=' '{print $2}'|sed "s|~|$HOME|"|xargs)

echo ""
git -C $roles_path config --get remote.origin.url
git -C $roles_path log --pretty="%h - %s" -3
