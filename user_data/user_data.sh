#!/bin/bash
echo "Running user data..." > /home/ec2-user/user_data.log
yum install -y vim  >> /home/ec2-user/user_data.log 
sudo yum install -y python3 >> /home/ec2-user/user_data.log 
sudo -u ec2-user pip3 install --user ansible
echo "User data completed." >> /home/ec2-user/user_data.log
echo "Ansible version:" >> /home/ec2-user/user_data.log
ansible --version >> /home/ec2-user/user_data.log
sudo -u ec2-user pip3 install --user ansible

#!/bin/bash
cd /tmp
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

#!/bin/bash
curl -fsSL https://tailscale.com/install.sh | sh
