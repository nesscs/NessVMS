This works!!
wget -O - https://github.com/kvellaNess/NxVMS/raw/master/nessvms.sh | bash
This Works!!

#Try and stop the updater
sudo service unattended-upgrades status
sudo service unattended-upgrades stop
sudo systemctl stop unattended-upgrades
sudo systemctl disable apt-daily.timer


top
sudo systemctl stop apt-daily.service
sudo systemctl kill --kill-who=all apt-daily.service
# wait until `apt-get updated` has been killed
while ! (systemctl list-units --all apt-daily.service | egrep -q '(dead|failed)')
do
  sleep 1;
done
echo "done"





systemctl stop apt-daily.service
systemctl kill --kill-who=all apt-daily.service
while ! (systemctl list-units --all apt-daily.service | fgrep -q dead)
do
  sleep 1;
done

#Wait for daily upgrade
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done

sed -E -i 's#http://[^\s]*archive\.ubuntu\.com/ubuntu#http://au.archive.ubuntu.com/ubuntu#g' /etc/apt/sources.list' /etc/apt/sources.list'

sudo sed -i 's|http://us.|http://ch.|g' /etc/apt/sources.list

sed -E -i 's#http://[^\s]*archive\.ubuntu\.com/ubuntu#http://au.archive.ubuntu.com/ubuntu#g' /etc/apt/sources.list'


sudo sed -i 's|http://archive.|http://au.archive.|g' /etc/apt/sources.list

References
https://github.com/Dhull442/Unattended-ubuntu16.04-install
