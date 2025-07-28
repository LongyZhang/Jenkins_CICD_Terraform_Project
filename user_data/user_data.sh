#!/bin/bash
echo "Running user data..." > /home/ec2-user/user_data.log
yum install -y vim  >> /home/ec2-user/user_data.log 
sudo yum install -y python3 >> /home/ec2-user/user_data.log 
sudo -u ec2-user pip3 install --user ansible
echo "User data completed." >> /home/ec2-user/user_data.log
echo "Ansible version:" >> /home/ec2-user/user_data.log
ansible --version >> /home/ec2-user/user_data.log
sudo -u ec2-user pip3 install --user ansible

