#!/usr/bin/env bash
NewRootPassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
NewUserPassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

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

ssh-keygen -b 4096 -t rsa -f CACid_rsa -q -N "";
if [ ! -d "~/.ssh" ]; then
	mkdir ~/.ssh
fi
cp CACid_rs* ~/.ssh/

expect -c "  
	set timeout 1
	spawn ssh root@${CACIP} \'mkdir .ssh\'
	expect \(yes\/no\)\? { send yes\r }
	expect password: { send ${DefaultRootPassword}\r }
	sleep 1
	exit
"

sleep 2

expect -c "  
	set timeout 1
	spawn scp CACid_rsa.pub root@${CACIP}:.ssh/authorized_keys
	expect password: { send ${DefaultRootPassword}\r }
	expect 100%
	sleep 1
	exit
"

ssh-add CACid_rsa
ssh -i CACid_rsa root@${CACIP} useradd -m ${NewUserName}
ssh -i CACid_rsa root@${CACIP} "echo ${NewUserName}:${NewUserPassword} | chpasswd"
ssh -i CACid_rsa root@${CACIP} usermod -a -G sudo ${NewUserName}
ssh -i CACid_rsa root@${CACIP} wget http://download.opensuse.org/repositories/network:bro/xUbuntu_14.04/Release.key
ssh -i CACid_rsa root@${CACIP} apt-key add Release.key
ssh -i CACid_rsa root@${CACIP} rm Release.key
ssh -i CACid_rsa root@${CACIP} apt update
ssh -i CACid_rsa root@${CACIP} apt-get -y -o Dpkg::Options::="--force-confnew" dist-upgrade
ssh -i CACid_rsa root@${CACIP} apt -y install bro fail2ban firefox iptables-persistent synaptic tcpdump vim wireshark xfce4 xfce4-dict xfce4-goodies xfce4-terminal xubuntu-icon-theme
ssh -i CACid_rsa root@${CACIP} service fail2ban stop
ssh -i CACid_rsa root@${CACIP} awk '{ printf "# "; print; }' /etc/fail2ban/jail.conf | sudo tee /etc/fail2ban/jail.local
ssh -i CACid_rsa root@${CACIP} iptables -F
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -i lo -j ACCEPT
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -p tcp --dport 22 -j ACCEPT
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -p tcp --dport 80 -j ACCEPT
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -p tcp --dport 443 -j ACCEPT
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -p tcp --dport 4000 -j ACCEPT
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -p upd --dport 22 -j ACCEPT
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -p udp --dport 80 -j ACCEPT
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -p udp --dport 443 -j ACCEPT
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -p udp --dport 4000 -j ACCEPT
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
ssh -i CACid_rsa root@${CACIP} iptables -A INPUT -j DROP
ssh -i CACid_rsa root@${CACIP} dpkg-reconfigure iptables-persistent
ssh -i CACid_rsa root@${CACIP} service fail2ban start
scp -i CACid_rsa NoMachine.deb root@${CACIP}:
ssh -i CACid_rsa root@${CACIP} dpkg -i NoMachine.deb
ssh -i CACid_rsa root@${CACIP} rm NoMachine.deb
ssh -i CACid_rsa root@${CACIP} /opt/bro/bin/broctl install
ssh -i CACid_rsa root@${CACIP} /opt/bro/bin/broctl start
ssh -i CACid_rsa root@${CACIP} echo "#!/usr/bin/env sh" >> /etc/init.d/S97-setup.sh
ssh -i CACid_rsa root@${CACIP} echo "/opt/bro/bin/broctl start" >> /etc/init.d/S97-setup.sh
ssh -i CACid_rsa root@${CACIP} reboot

rm CACid_rsa*

echo -e "\nMake sure you record these new passwords somewhere or you will be sad."
echo -e "\nroot password: ${NewRootPassword}"
echo -e "\n${NewUserName} password: ${NewUserPassword}"
