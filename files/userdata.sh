#!/bin/bash

# add extra ssh keys for convenience
cat <<EOF >>/home/ec2-user/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC+sMk/PqrzoQkfpRkdyResNwlzTFRZ0rBRWJlUdNZHP1yfsbWU/6C+qjaZqQ2VmM9Rv6nhXpfOpVZkIVvphS9knA5yR0w6zTy1v5E90tBUCCyjHRAjlQY2kdcwWg9zNSI6NvuKGM8281oKV8gP+gdXPgZjjdhG9U8ael3ftRs3508MJghIeGCEYq6r2llomE2Jnb8UOKn4ybt5mr6D24Xk1HlST/M/DrauSBGseMxrcoc66f/VkTNPKj2bniE8zWzgjB1ZxpMZyruovfDGOYOyl15bSodpyEXsLRFCsLA3i+m+cLLnTSTdQK7nROfYb/2tVXwa1YwUhgI/4DrmNjfOtpgTUChknWZt1Nqg/eC3y8fdYTaXdHUOgfmiGtA7bw9uu7ZTsQ2zpSZXgkPTLItPN4irOEXaeditBqUb6AoCqVhdMq/pJ+ot4L6WpYEJw67vAAJrSsZLh5R/X6GSFMHoa9t7xL2dbPNfo2GZ8fs3O/wmd86PpcwDamLJwLsS0ztYKLlW8gsZLnS0aRuCyTywSSKw7jopSjYPTxIS1M6rnrI72VYIL5rrQy3F22jYVkA30tqmyzOL/gVIVQjvafn9AGr8VnQ062d0Ud3HkxgaQ9XaT8kmrVDxexZ+pMVmyZGEqG2TlbYnAqB/kqqHenr5r4gLNaDnGbfwajZFdCCbxw== tom.j.v.brandon@gmail.com
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCfdZxWI6H+caoSMHdfYzx/gf12uWIw0YgNGDaO8Uai+rIulY1rTZdjZZZrQGE7U5ImI9CzGn0sAZ9MQo5wlQA7r+95rb962iqmYmKONPhPD+sB2+Z/xcOd9JqIfTYAfgJ7SlNc8P0neX75lI/YKvjPyAEa6qMznNDunGAE8MUrOxdpzgUlXeTEKaY5hI9NIwMuq1AkMlXujf1VwxreYbM6e1DmB2A/T2vzY3uRecRMKDN3STPaTuwnPuf0PLCPR/BYCcJtJOVqLPyZe9AT/lgvEzIN29xrsBCRzclkUjfGGT2zHGwUtlbm1cqDQMRmaY5W7uD9XA/96cMOH4reBNUP stang@ecsd-mbp16
EOF

echo "Started user data" > /home/ec2-user/test.txt

yum update -y
yum install docker -y
service docker start

bash -c "$(aws ecr get-login --region eu-west-1 --no-include-email)"
docker pull 674726326575.dkr.ecr.eu-west-1.amazonaws.com/mern-stack:${APP_VERSION}

PUBLIC_IP=$(curl -s ifconfig.io)

curl \
--user "${MONGODB_PUBLIC_API_KEY}:${MONGODB_SECRET_API_KEY}" --digest --include \
--header "Content-Type: application/json" \
--request POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/${MONGODB_GROUP_ID}/whitelist?pretty=true" \
--data "[{
\"cidrBlock\" : \"$PUBLIC_IP/32\",
\"comment\" : \"AWS EC2 Instance that host the 'mern-stack'\"
}]"

# sometimes, the 'whitelist' takes a bit of time so we simply 'sleep' to give
# it a chance to be 'effective' before we go further down
# note: this is not a proper solution but this workaround should be 'good enough' for the purpose of this exercise
sleep 60

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

docker container run -itd --rm --env DANGEROUSLY_DISABLE_HOST_CHECK=true \
--env "MONGODB_ACCESS=${MONGODB_ACCESS}" \
--env JWT_SECRET=${JWT_SECRET} \
--env GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID} \
--env GITHUB_SECRET=${GITHUB_SECRET} \
-p 80:3000 -p 5000:5000 --name super-mern-stack 674726326575.dkr.ecr.eu-west-1.amazonaws.com/mern-stack:${APP_VERSION}
EOF

sudo service mern-stack start
