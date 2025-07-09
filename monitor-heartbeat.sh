#!/usr/bin/zsh

# locations of data
fileshare_dest_dir=/groups/otopalik/otopaliklab/songtorrent_data

# cluster parameters
cluster_head_node=login1.int.janelia.org
email_addr=arthurb@janelia.hhmi.org

# nominal heartbeat period in HHMMSS
heart_period=10000

time_of_lastbeat=$(ssh -l otopalikrobot $cluster_head_node tail -1 $fileshare_dest_dir/diff-rsync-logs/heartbeat.log)
time_now=$(date +%Y%m%d%H%M%S)

(( $time_now - $time_of_lastbeat < $heart_period )) ||
        mail -s "otopalikrobot failed" "$email_addr" < /dev/null
