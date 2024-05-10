#!/bin/bash

######### ** FOR 2nd master NODE ** #########

hostname k8s-msr-2
echo "k8s-msr-2" > /etc/hostname

export AWS_ACCESS_KEY_ID=${access_key}
export AWS_SECRET_ACCESS_KEY=${private_key}
export AWS_DEFAULT_REGION=${region}
export AWS_SESSION_TOKEN=${session_token}

apt update
apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

#Installing Docker
tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter


apt update
apt-cache policy docker-ce
apt install docker-ce -y
apt install awscli -y

#Be sure to understand, if you follow official Kubernetes documentation, in Ubuntu 20 it does not work, that is why, I did modification to script
#Adding Kubernetes repositories

#Next 2 lines are different from official Kubernetes guide, but the way Kubernetes describe step does not work
# curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add
# echo "deb https://packages.cloud.google.com/apt kubernetes-xenial main" > /etc/apt/sources.list.d/kurbenetes.list

mkdir -p /etc/apt/keyrings/
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


#Turn off swap
swapoff -a
sudo sed -i '/swap/d' /etc/fstab
mount -a
ufw disable

#Installing Kubernetes tools
apt update
# apt install kubelet kubeadm kubectl -y
apt install -y kubeadm=1.28.1-1.1 kubelet=1.28.1-1.1 kubectl=1.28.1-1.1


#next line is getting EC2 instance IP, for kubeadm to initiate cluster
#we need to get EC2 internal IP address- default ENI is eth0
export ipaddr=`ip address|grep eth0|grep inet|awk -F ' ' '{print $2}' |awk -F '/' '{print $1}'`


# the kubeadm init won't work entel remove the containerd config and restart it.
rm /etc/containerd/config.toml
systemctl restart containerd

tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# to insure the join command start when the installion of master node is done.
sleep 1m


aws s3 cp s3://${s3buckit_name}/join_master_command.sh /tmp/.
chmod +x /tmp/join_master_command.sh

echo " --apiserver-advertise-address=$ipaddr" >> /tmp/join_master_command.sh

# Remove the backslash character

tr -s '\\' " " < /tmp/join_master_command.sh > /tmp/join_master_command_tmp.sh

# add to single line

#paste -s -d " " /tmp/join_master_command.sh > /tmp/join_master_command_tmp.sh && mv join_master_command_tmp.sh /tmp/join_master_command.sh

paste -s -d " " /tmp/join_master_command_tmp.sh > /tmp/join_master_command_tmp2.sh

sudo bash /tmp/join_master_command_tmp2.sh

aws s3 cp /tmp/join_master_command_tmp2.sh s3://${s3buckit_name}

#this adds .kube/config for root account, run same for ubuntu user, if you need it
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
cp -i /etc/kubernetes/admin.conf /tmp/admin.conf
chmod 755 /tmp/admin.conf

#Add kube config to ubuntu user.
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chmod 755 /home/ubuntu/.kube/config

