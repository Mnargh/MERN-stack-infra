#!/bin/bash

# add extra ssh keys for convenience
cat <<EOF >>/home/ec2-user/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCfdZxWI6H+caoSMHdfYzx/gf12uWIw0YgNGDaO8Uai+rIulY1rTZdjZZZrQGE7U5ImI9CzGn0sAZ9MQo5wlQA7r+95rb962iqmYmKONPhPD+sB2+Z/xcOd9JqIfTYAfgJ7SlNc8P0neX75lI/YKvjPyAEa6qMznNDunGAE8MUrOxdpzgUlXeTEKaY5hI9NIwMuq1AkMlXujf1VwxreYbM6e1DmB2A/T2vzY3uRecRMKDN3STPaTuwnPuf0PLCPR/BYCcJtJOVqLPyZe9AT/lgvEzIN29xrsBCRzclkUjfGGT2zHGwUtlbm1cqDQMRmaY5W7uD9XA/96cMOH4reBNUP stang@ecsd-mbp16
EOF

echo "Started user data" > /home/ec2-user/test.txt

sudo yum update -y
sudo yum install docker -y
sudo service docker start
bash -c "$(aws ecr get-login --region eu-west-1 --no-include-email)"
docker pull 674726326575.dkr.ecr.eu-west-1.amazonaws.com/mern-stack:v4

## Whitelists instance IP
# curl --user "zwbjetqj:fe3d8cdf-33f5-442e-aacb-41ae7b29211e" --digest --include \    (master✱) 
#   --header "Accept: application/json" \
#   --header "Content-Type: application/json" \
#   --request POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/5e2601bc553855b403e9fc89/whitelist?pretty=true" \
#   --data '[{
#         "cidrBlock" : "54.73.108.178/32",
#         "comment" : "CIDR block for mern instance"
#       }]'


aws ec2 describe-instances \
  --filters "Name=tag:Name,Values='mern_stack_instance'" "Name=instance-state-name,Values=pending,running" \
  --query "Instances[*].PublicIpAddress" \ 
  --output=text


  


cat <<'EOF' >> /etc/systemd/system/mern-stack.service
[Unit]
Description="Sets up mern-stack container"

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'bash /home/ec2-user/set-up-container.sh'
Restart=no

[Install]
WantedBy=multi-user.target
EOF

cat <<'EOF' >> /home/ec2-user/set-up-container.sh
#!/bin/bash

docker container run -itd --rm --env DANGEROUSLY_DISABLE_HOST_CHECK=true -p 80:3000 -p 5000:5000 --name super-mern-stack 674726326575.dkr.ecr.eu-west-1.amazonaws.com/mern-stack:v4
EOF

sudo service mern-stack start