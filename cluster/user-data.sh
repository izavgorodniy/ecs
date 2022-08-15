#!/bin/bash

set -e

sudo yum update -y
sudo yum install docker -y
sudo mkdir /etc/ecs
sudo touch /etc/ecs/ecs.config


echo ECS_CLUSTER=test-app >> /etc/ecs/ecs.config

cat << EOF > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo service docker restart
