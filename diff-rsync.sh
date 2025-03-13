#!/usr/bin/zsh

# locations of data
windows_src_dir=/mnt/d/Otopalik/
fileshare_dest_dir=/groups/otopalik/otopaliklab/songtorrent_data
analyze_executable=/groups/otopalik/home/otopalikrobot/SongExplorer/classify-ethogram.sh
datadir_regex='[0-9]{8}_[0-9]{6}_[0-9]{7}JL5'

# cluster parameters
cluster_head_node=login1.int.janelia.org

# before copying data, determine what is new
dirs_to_analyze_str=`diff <(ls $windows_src_dir) <(ssh $cluster_head_node ls $fileshare_dest_dir) | \
                     grep '^< ' | grep -E $datadir_regex | \
                     sed -r 's/^< //'`
dirs_to_analyze=("${(f)dirs_to_analyze_str}")

# copy data to fileshare
echo copying data
rsync -av --no-perms $windows_src_dir otopalikrobot@$cluster_head_node:/$fileshare_dest_dir

# analyze data in each new folder
logfile=$HOME/classify-ethogram.$(date +\%Y\%m\%d\%H\%M\%S).log
for wavdir in $dirs_to_analyze ; do
    echo analyzing $wavdir
    ssh $cluster_head_node $analyze_executable $wavdir -o $logfile -e $logfile
done
