#!/usr/bin/env bash

#######################################################################################################
# Thank the flying toasters for the Digital Ocean wiki and stack exchange
# This version isn't a total pile of hott garbage, but we're still doing echo debugging

#######################################################################################################
# Generate new random 16 char passwords
NewRootPassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
NewUserPassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

#######################################################################################################
# Get some variables from the user
read -r -p "What is the CAC IP:       #: " CACIP;
while [[ ${CACIPSet} != "y" ]]; do
        if [[ ${CACIP} == "" ]]; then
                read -r -p "What is the CAC IP:       ${CACIP}: " CACIP;
        else
                read -r -p "CAC IP is: ${CACIP}                   (y or n) : " CACIPSet
                if [[ ${CACIPSet} != "y" ]]; then
                        read -r -p "What is the CAC IP:       ${CACIP}: " CACIP;
                fi
        fi
done

read -r -p "What is the root password:       #: " DefaultRootPassword;
while [[ ${DefaultRootPasswordSet} != "y" ]]; do
        if [[ ${DefaultRootPassword} == "" ]]; then
                read -r -p "What is the root password:       ${DefaultRootPassword}: " DefaultRootPassword;
        else
                read -r -p "Root password is: ${DefaultRootPassword}                   (y or n) : " DefaultRootPasswordSet
                if [[ ${DefaultRootPasswordSet} != "y" ]]; then
                        read -r -p "What is the root password:       ${DefaultRootPassword}: " DefaultRootPassword;
                fi
        fi
done

read -r -p "What is the new user name:       #: " NewUserName;
while [[ ${NewUserNameSet} != "y" ]]; do
        if [[ ${NewUserName} == "" ]]; then
                read -r -p "What is the new user name:       ${NewUserName}: " NewUserName;
        else
                read -r -p "New user name is: ${NewUserName}                   (y or n) : " NewUserNameSet
                if [[ ${NewUserNameSet} != "y" ]]; then
                        read -r -p "What is the new user name:       ${NewUserName}: " NewUserName;
                fi
        fi
done

#######################################################################################################
# Generate new SSH key pair
ssh-keygen -b 4096 -t rsa -f CACid_rsa -q -N "";
if [ ! -d "~/.ssh" ]; then
	mkdir ~/.ssh
fi
cp CACid_rsa* ~/.ssh/

#######################################################################################################
# Log into server and install SSH pub key. This is kinda hacky, and might need some work
echo ""
expect -c "  
	set timeout 9
	spawn ssh root@${CACIP} mkdir /root/.ssh/
	sleep 3
	expect \(yes\/no\)\? { send yes\r }
	sleep 3
	expect password: { send ${DefaultRootPassword}\r }
	sleep 3
	exit
"
echo ""
expect -c "  
	set timeout 6
	spawn scp CACid_rsa.pub root@${CACIP}:/root/.ssh/authorized_keys
	sleep 3
	expect password: { send ${DefaultRootPassword}\r }
	expect 100%
	sleep 3
	exit
"

#######################################################################################################
# Install new SSH key pair on local box
ssh-add ~/.ssh/CACid_rsa
sleep 3;

#######################################################################################################
# Create new users on CAC and add them to sudo, also change root password
ssh -i ~/.ssh/CACid_rsa root@${CACIP} useradd -m ${NewUserName}
ssh -i ~/.ssh/CACid_rsa root@${CACIP} chsh -s /bin/bash ${NewUserName}
ssh -i ~/.ssh/CACid_rsa root@${CACIP} "echo ${NewUserName}:${NewUserPassword} | chpasswd"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} usermod -a -G sudo ${NewUserName}
#######################################################################################################
# This is working kinda weird so we're commenting it out for now
#echo -e "\n\n01\n\n"
#ssh -i ~/.ssh/CACid_rsa root@${CACIP} "echo root:${NewRootPassword} | chpasswd"

#######################################################################################################
# Add repositories, run updates, and install junk
echo -e "\n\n02\n\n"
scp -i ~/.ssh/CACid_rsa bro.list root@${CACIP}:/etc/apt/sources.list.d/bro.list
echo -e "\n\n03\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} wget http://download.opensuse.org/repositories/network:bro/xUbuntu_14.04/Release.key
echo -e "\n\n04\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} apt-key add Release.key
echo -e "\n\n05\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} rm Release.key
echo -e "\n\n06\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} apt update
echo -e "\n\n07\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} apt-get -y -o Dpkg::Options::="--force-confnew" dist-upgrade
echo -e "\n\n08\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} apt -y install fail2ban firefox fontconfig iptables-persistent synaptic tcpdump vim wireshark xfce4 xfce4-terminal xfce4-dict xfce4-goodies xfce4-netload-plugin xubuntu-icon-theme
echo -e "\n\n09\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
echo -e "\n\n10\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} service fail2ban stop

#######################################################################################################
# Firewall all the things
echo -e "\n\n11\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -F
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -i lo -j ACCEPT
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -p tcp --dport 22 -j ACCEPT
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -p tcp --dport 80 -j ACCEPT
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -p tcp --dport 443 -j ACCEPT
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -p tcp --dport 4000 -j ACCEPT
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -p udp --dport 22 -j ACCEPT
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -p udp --dport 80 -j ACCEPT
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -p udp --dport 443 -j ACCEPT
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -p udp --dport 4000 -j ACCEPT
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
ssh -i ~/.ssh/CACid_rsa root@${CACIP} iptables -A INPUT -j DROP
ssh -i ~/.ssh/CACid_rsa root@${CACIP} dpkg-reconfigure iptables-persistent
ssh -i ~/.ssh/CACid_rsa root@${CACIP} service fail2ban restart

#######################################################################################################
# Get NoMachine installed for easy peasy remote desktop
echo -e "\n\n12\n\n"
scp -i ~/.ssh/CACid_rsa NoMachine.deb root@${CACIP}:
echo -e "\n\n13\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} dpkg -i NoMachine.deb
echo -e "\n\n14\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} rm NoMachine.deb

#######################################################################################################
# Get Bro IDS installed because I'm a bro bro and bro is the way to be a bro bro bro.
echo -e "\n\n15\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} /opt/bro/bin/broctl install
echo -e "\n\n16\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} /opt/bro/bin/broctl start
echo -e "\n\n17\n\n"
scp -i ~/.ssh/CACid_rsa S97-setup.sh root@${CACIP}:/etc/init.d/S97-setup.sh
echo -e "\n\n18\n\n"
ssh -i ~/.ssh/CACid_rsa root@${CACIP} reboot

#######################################################################################################
# rm SSH keypair from pwd
rm CACid_rsa*

#######################################################################################################
# Tell user that they need to use the passwords we generated up top
echo -e "\n\nMake sure you record the new passwords somewhere or you will be sad.\nYou can find them in CAC_${CACIP}.txt\n\n"
touch CAC_${CACIP}.txt
echo -e "CAC IP : ${CACIP}" >> CAC_${CACIP}.txt
echo -e "\nroot : ${NewRootPassword}" >> CAC_${CACIP}.txt
echo -e "\n${NewUserName} : ${NewUserPassword}" >> CAC_${CACIP}.txt
cat CAC_${CACIP}.txt
