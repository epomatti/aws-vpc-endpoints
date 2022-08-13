#!/usr/bin/env bash

# Update & Upgrade
sudo apt-get update
sudo apt-get upgrade -y

# Utilities
sudo apt install traceroute -y

# AWS CLI
sudo apt install unzip -y
sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo unzip awscliv2.zip
sudo ./aws/install
