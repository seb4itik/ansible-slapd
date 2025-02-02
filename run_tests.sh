#!/bin/sh

ANSIBLE_CONFIG=tests/ansible.cfg

for play in tests/play-test001.yml
do
  ansible-lint --strict $play && time ansible-playbook $play $*
done
