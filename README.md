A set of scripts to automatically transfer data from rig computers to the
fileshare and analyze them with the cluster.

An alternative to [transfero](https://github.com/JaneliaSciComp/transfero).
Uses [WSL2](https://learn.microsoft.com/en-us/windows/wsl/) instead of
[cygwin](https://www.cygwin.com/) on the rig computer.  Further, the rig
computer, not the cluster, has the cron job which does the copy.  All in shell
instead of python.

### Installation ###

In a PowerShell terminal:

    wsl --install

After rebooting, open a WSL terminal.

If the D: drive on the Windows side is not already mounted to /mnt/d then:

    sudo mkdir /mnt/d
    sudo echo 'D: /mnt/d drvfs defaults 0 0' >> /etc/fstab
    sudo mount -a

Add a user for the robot:

    sudo adduser otopalikrobot

The scripts use zsh (not bash), so install it and set it as the default shell:

    sudo apt install zsh
    su -l otopalikrobot
    chsh -s $(which zsh)

Copy "diff-rsync.sh" from this repo to the robot's home folder.  Then set its
execution bit:

    chmod a+x diff-rsync.sh

And schedule it to automatically run every day at 2 AM:

    crontab -e
    # 0 2 * * * $HOME/diff-rsync.sh > $HOME/diff-rsync.$(date +\%Y\%m\%d\%H\%M\%S).log

Enable password-less ssh access to the cluster login node by first generating a
RSA key pair on the rig computer:

    ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa

And then manually copying .ssh/id_rsa.pub on the rig computer to
.ssh/authorized_keys on the cluster fileshare.

While logged into the cluster, copy "classify-ethogram.sh" from this repo into
the robot's home folder, and set its execution bit too:

    chmod a+x classify-ethogram.sh

Examine the various configuration parameters stored in variables at the top of
each of these two scripts.  Change as necessary.  Hopefully their names of
descriptive enough.

If there are already data to analyze, check the everything works by doing so
manually:

    ./diff-rsync.sh

Lastly, ensure these scripts will continue to run automatically if the computer
reboots:

    Open the Task Scheduler

    Create a new task:
    Click "Action" > "Create Basic Task"
    Give your task a name like "Start WSL on Startup". 

    Set trigger:
    Select "When the computer starts" as the trigger. 

    Set action:
    Select "Start a program" as the action. 
    Browse to the "wsl.exe" executable file (usually located in "C:\Windows\System32\wsl.exe"). 

    Set permissions (important):
    Go to the "General" tab of the task properties. 
    Check the "Run whether user is logged on or not" option. 
    Set "Run with highest privileges". 

On Windows 11 you might also need to update the WSL configuration by adding
these lines to C:\Users\<UserName>\.wslconfig:

    [wsl2]
    vmIdleTimeout=-1

### Monitoring ###

To check that the scripts are executing as scheduled, add this to the crontab,
and reboot:

    * * * * * ssh login1 "echo $(date +\%Y\%m\%d\%H\%M\%S) >> heartbeat.log"

On a different machine, say your Linux workstation, add this to its crontab:

    0 6 * * * /groups/scicompsoft/home/arthurb/projects/otopalik/monitor-heartbeat.sh

You will receive an email in the morning if the Windows box's crontab isn't
working.

### Notes ###

I previously tried to make it reboot-safe with the following, but it seemed not
to work:

	Make a file called perpetual-wsl.bat in Windows with the following contents:
		wsl.exe --exec dbus-launch true
	Add a shortcut to perpetual-wsl.bat in the windows start-up folder:
		`run shell:startup` and drag and drop
