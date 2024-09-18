# Proxy Install

_The document will go through the steps to run an install in GCP with proxy information_.

1. Create an N4 Instance

Add the service account for your user to the machine. Allow all firewall rules.

2. Spin up the virtual machine and ssh in.

3. Install the `epel-release` repo.

4. Install the following packages:

```
jq
wget
ncurses
python3-pip
unzip
groff
emacs
squid
httpd-tools
```

5. install yq via wget

```bash
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
```

6. `sudo systemctl start squid`

7. Add the passwords files for squid

```bash
sudo touch /etc/squid/passwords
sudo chmod 777 /etc/squid/passwords
```

8. Add passwords and user to squid

```bash
htpasswd -c /etc/squid/passwords $USER
```

9. Edit squid config file

```bash
sudo rm -rf /etc/squid/squid.conf && sudo emacs /etc/squid/squid.conf
```

Enter the following information:

```
http_port 3128                                                                                                                                                                                                      
cache deny all                                                                                                                                                                                                      
access_log stdio:/tmp/squid-access.log all                                                                                                                                                                          
debug_options ALL,1                                                                                                                                                                                                 
shutdown_lifetime 0                                                                                                                                                                                                 
auth_param basic program /usr/lib64/squid/basic_ncsa_auth /squid/passwords                                                                                                                                          
auth_param basic realm proxy                                                                                                                                                                                        
acl authenticated proxy_auth REQUIRED                                                                                                                                                                               
http_access allow authenticated                                                                                                                                                                                     
pid_filename /tmp/proxy-setup
```

10. `sudo systemctl restart squid`

11. Check that the port is open

```bash
netstat -tuplen
```

You should see port 3128 open.

_Note: There is an open bug for this type of install. The bug is for passwords not being escaped and applied correctly when added to the install config_. 