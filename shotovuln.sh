#!/bin/bash

echo "SHOTOVULN v0.2        *0* Senseiiii show me the path to R00t *o* "
# insert ASCII art =)
echo "Usage: $0 [currentpassword] [brute] [network] [nosuidaudit] [pupy] [msf]";
echo "Vulnerabilities found will be output under each [x] test";
# source : github 444xxk/shotovuln

# PHILOSOPHY for devs
# - non interactive shell 
# - stealth, try not to touch drive except if needed, try to run everything in memory
# - do not output useless information, only valid vuln or nothing
# - run as low privilege user
# - show clear path to root
# - no colors, can be used outside of standard terminals
# - user should pipe output to file for better read
# - try to document the vuln example in comments (ie CVE-xxx CWE weakness)
# requirement on the compromised box : *nix OS, bash [+ python , pip: for brute]
# typical usage: you get a webshell on *nix and you want to elevate

# TODO code all ideas already present in comments work and finalize it for v3 
# TODO need to check if "find" is the best cmd to check permissions
# TODO limit find to maxdepth to avoid long scan time

echo "";
echo "### 0. Pre work";

brute=false;
network=false;
suid=false;
declare -a passfounds;

# if root exit test 

# brutefroce network packets or SUID running might be noisy, so these are disabled by default 
if [ "$2" == "brute" ] ; then brute=true; echo "[B] brute mode"; else echo "[NB] no bruteforce" ; fi
if [ "$3" == "network" ] ; then network=true; echo "[N] network allowed"; else echo "[NN] network not allowed"; fi
if [ "$4" == "suidaudit" ] ; then suid=true; echo "[S] SUID binaries audit allowed"; else echo "[NS] suid testing not allowed"; fi
# start a pupy RAT session to use pupy post exploit modules
# start a meterptr session to use msf local exploit modules


echo "[o] Saving writable folders for everyone, useful for next steps";
writabledirs=$(find / -maxdepth 5 -type d -perm /o+w ! -path "*mqueue*" 2>/dev/null);
writedir=$(echo "$writabledirs" | head -n1);
echo "[o] Will use as writable dir: $writedir";

tooldir="$(pwd)/tools/";
echo "[o] Tools dir is: $tooldir"

currentuser=$(id);
currentgroup=$(groups);
echo "[o] Current user and privileges is: $currentuser and groups: $currentgroup";

if [ $network == true ]; then
 if [ ! -f "$writedir/.wordlist" ]; then
 echo "[o] Getting quality short password wordlist from web";
 wget -qO "$writedir/.wordlist" "https://raw.githubusercontent.com/berzerk0/Probable-Wordlists/master/Real-Passwords/Top220-probable.txt"; # copy into own git
 fi;
fi;


echo "[o] Getting valid users for login";
validusers=$(grep -v '/false' /etc/passwd | grep -v '/nologin' | cut -d ':' -f1);

if [ $brute == true ]; then
 passwords="$writedir/.wordlist";
 # python and pip needed on the box TODO test here
 if ( which python );  then pip install pexpect; pythonandpip=true; fi;
fi;





echo "";
echo "### 1. Auditing feature-like paths to go to other privileges"
echo "[x] Getting SSH permissions";
if [ -f /etc/ssh/sshd_config ]; then
    sshperm=$(grep -niR --color permit /etc/ssh/sshd_config);
fi;
# echo "[debug] : $sshperm";

echo "[x] Getting allow users (if any) in SSH config"
if [ -f /etc/ssh/sshd_config ]; then
    sshusers=$(grep -niR --color allowusers /etc/ssh/sshd_config);fi;
# echo "[debug]: $sshusers";

if [ -f /etc/ssh/sshd_config ]; then
sshport=$(grep Port /etc/ssh/sshd_config | cut -d ' ' -f2);
fi;


# sudo and su brute https://www.altsci.com/concepts/sudo-and-su-considered-harmful-sudosu-bruteforce-utility
if [ ! -z "$1" ] ; then
echo " ! Currentuser password provided ! ";
echo "[x] Checking what you can do with sudo with this password, ie. going to root"; # example no CVE feature
# TODO non interactive here

# TODO idea for sudo: list programs that escalate through NOPASSWD. eg some guys think it's a good idea to nopasswd vim, nano, nmap...etc but in these cases you get root.

sudo -l;
elif [ $brute == true ]; then
 echo " ! No password provided ! "
 echo "[x] Bruteforcing the loggedin user password through SUDO with python scripts"; # example CWE weak password
 # TODO faster sudo bruteforcer, using python child / pexpect
 # python $tooldir/sudo_brute1.py < "$passwords" ; # here use a better script or smaller wordlist

 echo "[x] Brute forcing local users password through SU with python scripts"; # example CWE weak password
 # python $tooldir/su_brute1.py < $password;


 echo "[x] Now bruting valid users on SSH ports using ssh passcript"; # example CWE weak password
 # $tooldir/getsshpass-0.8.sh "$passwords";
 # else exit;

fi;





# TODO check if dmesg allows you to privesc 
# echo "Do we have access to dmesg and check privesc related information ?" ie can we elevate with dmesg info ? 
#dmesg script;





echo "";
echo "### 2. Auditing file and folders permissions for privesc"

echo "[x] Simply cating /etc/shadow and /etc/shadow derivatives, ie. might be lucky"; #CVE-xxx CWE weak file folder permissions
cat /etc/shadow 2>/dev/null;
cat /etc/shadow.* 2>/dev/null;
find / 2>/dev/null -readable -name '/*shadow*' -exec grep -n ':/' {} +;

echo "[x] Checking readable default private RSA keys in home folders, ie. wrong RSA key permissions"; #CVE-xxx CWE weak file folder permissions
for user in $validusers; do cat "/home/$user/.ssh/id_rsa" 2>/dev/null; done
# TODO extend filename, remove currentuser key

echo "[x] Root owned files in non root owned directory, ie. other can replace root owned files or symlink"; #example CVE-2016-1247 nginx package vuln, CWE weak file folder permissions
for x in $(find /var -type f -user root 2>/dev/null -exec dirname {} + | sort -u); do (echo -n "root files in folder $x owned by " && stat -c %U "$x") | grep -v 'root'; done

echo "[x] Writable directory in default PATH, ie. other can tamper PATH of scripts which run automatically"; #example CVE-xxx
pathstotest=$(echo "$PATH" | tr ':' '\n');
for path in $pathstotest; do find "$path" 2>/dev/null -type d -perm /o+w -exec ls -alhd {} +; done

echo "[x] Checking usual temporary folders for passwords or secrets and storing them, i.e. other can use the password to elevate or test password reuse"; # example CVE-xxx CWE info disclosure
find /tmp/  2>/dev/null -type f -size +0 -exec grep -i 'secret/|password/|' {} +;
find /dev/shm  2>/dev/null -type f -size +0 -exec grep -i 'secret/|password/|' {} +;
# TODO hash find in this content

echo "[x] Checking crontab script protection, ie. other can write to crontab scripts" #example CVE-xxx
for user in $validusers; do
writablescripts=$(grep --color "$user" /etc/crontab | cut -f4 | cut -d ' ' -f1 | sort -u);
for script in $writablescripts; do find $(which "$script") 2>/dev/null -perm /o+w -exec ls -alh {} +; find "$script" 2>/dev/null -perm /o+w -exec ls -alh {} +; done;
done

# /dev/mem device permission
echo "[x] Checking /dev/mem device permissions, ie. user can elevate by reading to it, trying to extract useful information";
find /dev/mem -readable 2>/dev/null -exec ls -alh {} +;


# TODO check not hardcoded /home but valid users home
# check github.com/51x/LUI for users script


echo "";
echo "### 3. Auditing SUID/SGID and SUID/SGID operations, without arguments provided";
### https://www.pentestpartners.com/blog/exploiting-suid-executables/;
echo "[x] SGID folders writable by others, ie. other can get group rights by writing to it"; #example CVE-xxx
find / -type d -perm /g+s -perm /o+w -exec ls -alhd {} + 2>/dev/null;
#find / -type d -perm /g+s -writable -exec ls -alhd {} + 2>/dev/null; # TODO writable by you but access to other group
echo "[x] SUID folders writable by others, ie. other can get user rights by writing to it"; #example CVE-xxx
find / -type d -perm /u+s -perm /o+w -exec ls -alhd {} + 2>/dev/null;
#find / -type d -perm /u+s -writable -exec ls -alhd {} + 2>/dev/null;
# TODO add not current user test ie ! -user $currentuser ;
if [ $suid == true ] ; then
# TODO be careful not to kill network with SUID
# TODO echo "Test SUID conf files for error based info disclosure"
# TODO code it --conf / -c / grep conf in help
# example ./suidbinary -conf /etc/shadow outputs the user hashes
echo "[x] Generating SUID logs ... you might receive some pop ups and error message since we are starting all SUID binaries.";
mkdir -p "$writedir/.shotologs";

find / -perm /4000 2>/dev/null | sort -u > "$writedir/.suidbinaries";
while read -r suid; do
echo "[debug: started $suid]";
basename=$(basename "$suid");
#sleep 6s;
# TODO bugfix here the script stops at the middle of the list
timeout 13s strace "$suid" 2>"$writedir"/.shotologs/"$basename".stracelog 1>/dev/null ;
done < "$writedir/.suidbinaries";

# add this generic vuln , SUID root loading from writable dir :/
# https://www.exploit-db.com/exploits/41907/
echo "[x] Relative path opening in SUID binaries, ie. other can fool the SUID binary to open arbitrary files." #example CVE-xxx
grep -n 'open("\.' "$writedir"/.shotologs/* --color;
grep -n 'open(' "$writedir"/.shotologs/* | grep -v 'open("/';
echo "[x] Environment variables used in suid binaries, ie. other can inject into env, untrusted use of env variables." #example CVE-xxx
grep -n --color "getenv(" "$writedir"/.shotologs/*;
echo "[x] Exec used in SUID binaries, ie. other can fool SUID use of PATH, untrusted use of PATH." #example CVE-xxx
grep -n --color 'execve(\.' "$writedir"/.shotologs/*;

fi;




echo "";
echo "### 4. Specific edge cases which enable you to change privilege"
echo "[x] Apache symlink test, ie. allows other to check files and folders of other users using the shared apache account"; #example no CVE but feature
find / 2>/dev/null -name "apache*.conf" -exec grep -n -i 'Options +FollowSymLinks' {} +;
find / 2>/dev/null -name "httpd.conf" -exec grep -n -i 'Options +FollowSymLinks' {} +;
echo "[x] Pythonpath variable issues, ie. if PATH is vulnerable and a python privilege script runs, other can inject into its PATH"; #example CVE-xxx
pythonpath=$(python -c "import sys; print '\n'.join(sys.path);")
for path in $pythonpath; do find "$path" 2>/dev/null -type d -perm /o+w -exec ls -alhd {} +; done
echo "[x] Checking terminals permissions, ie. other can write or read from other user terminals and get their privileges"; #example CVE-xxx
find /dev/pts/ 2>/dev/null -perm /o+r -exec ls -alh {} +;
#find /dev/tty* 2>/dev/null -perm /o+r -exec ls -alh {} +;
# echo "[x] Checking DBUS vulnerabilities [WIP]" ; # example CVE-2017-8422 (KAuth) and CVE-2017-8849 (smb4k)
#TODO use python to check dbus isssues ?


echo "";
echo "### 5. Init.d and RC scripts auditing";
### The problem is service (init.d) strips all environment variables but TERM, PATH and LANG which is a good thing
# http://www.yolinux.com/TUTORIALS/LinuxTutorialInitProcess.html
# https://serverfault.com/questions/374404/service-command-and-environment-variables
echo "[x] RC.local scripts pointing to vulnerable directory, ie. other can write to it and get root privilege"; # example CVE-xxx
pathstoaudit=$(grep  '^/' /etc/rc.local | cut -d ' ' -f1); # need better regex this suxx
for path in $pathstoaudit; do
find "$path" 2>/dev/null -perm /o+w -exec ls -alh {} +;
find "$path" 2>/dev/null -writable -exec ls -alh {} +;
done;
echo "[x] Check if users can restart services";
# TODO code it
echo "[x] Init.d scripts using unfiltered environment variables, ie. user can inject into it and get privilege"; #example CVE-xxx
echo "[debug] need better filtering"; # need better filtering
grep -R -v 'PATH=\|LANG=\|TERM=' /etc/init.d/* | grep " PATH\| LANG\| TERM" | grep -v '#' | grep -v 'export';
# TODO confirm this is exploitable , better regexp , remove commented line
# race PATH inject before init.d is starting
# init.d is starting early
echo "[x] Usage of predictable or fixed files in a writable folder used by init.d, ie. other can race and symlink file creation"; # example CVE-xxx
echo "[debug] need better filtering"; # need better filtering
# TODO list all path used by init, filter writable ones
# TODO better regex
grep -R '/tmp' /etc/init.d/* | grep -v '#';





echo "";
echo -e "### 6. Configuration files, password disclosure and password reuse";
echo "[x] Checking readable passwords used in .conf files, ie. other can read and use them or try password reuse";
conffiles=$(find / -type f -readable 2>/dev/null -name "*.conf" | sort -u);
for file in $conffiles; do
 if (grep -i "password =\|password=\|password :\|password:" "$file" | grep -E "^#" -v); then echo " ! Passwords found in $file" ; fi;
done
#find / 2>/dev/null -name "*.conf"  -exec grep -n -i "password =\|password=\|password :\|password:" {} +;
# TODO filter false positives, filter comments
echo "[x] Checking writable .conf files, ie current user cannot modify them to achieve privesc" # example CWE
find /etc 2>/dev/null -name "*.conf" -writable;



echo "";
echo "### 7. Log file information disclosure";
echo "[x] Checking history files and harvesting info, ie. other can read password and try password reuse"; # example CWE file folder permission
find / 2>/dev/null -name "*history"  -exec grep -n -i "password\|pass\|\-p" {} +;
# $validusers history grepping
echo "[x] Checking log files for passwords, ie. other can read and try password reuse";
find / 2>/dev/null -name "*.log" -exec grep -n -i "password" {} +;



echo "";
echo "### 8. Database file information disclosure";
echo "[x] Checking passwords inside local databases file"
sqlitefiles=$(find / 2>/dev/null -name "*.sqlite" -readable);



echo "";
echo "### X. Privesc matrix";
# we might need to create a matrix of user privs
echo "[x] Creating a matrix of user privileges possibilities ..."
echo "[debug] sample : $currentuser > user2 > user9 > group1 > root(group) > root";
# BIG TODO , map the privilege , ie like user1 > user2 > user3 > root
# privescpath=(user1,user2);(user2,root)
