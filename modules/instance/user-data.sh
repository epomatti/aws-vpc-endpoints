#!/usr/bin/env bash
su ec2-user

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Update
sudo apt update
sudo apt upgrade -y

# Utilities
sudo apt install unzip traceroute -y

# AWS CLI
sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
