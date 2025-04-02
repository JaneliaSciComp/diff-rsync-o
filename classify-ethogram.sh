#!/usr/bin/zsh

wavdir=$1

# location of data
fileshare_dest_dir_prfs=/groups/otopalik/otopaliklab/songtorrent_data

# cluster parameters
bsub_flags=(-P otopalik -u arthurb@hhmi.org)
jobid_regex='Job <\([0-9]*\)> '

# songexplorer parameters
songexplorer_zip_dir=/groups/otopalik/home/otopalikrobot/SongExplorer/songexplorer-0.8beta-linux
songexplorer_config_file=/groups/otopalik/home/otopalikrobot/SongExplorer/configuration.py
songexplorer_model_logdir=/groups/otopalik/home/otopalikrobot/SongExplorer/nf32_mb32
songexplorer_model_replicate=train_1r
songexplorer_model_nsteps=3900000


# automatically gather up additional parameters

python_read_config_cmd=exec\(open\(\"$songexplorer_config_file\"\).read\(\)\)
function parse_config_file {
    local val=`python -c "$python_read_config_cmd; print($1)"`
    echo ${val//\'/}
}
classify_cluster_flags=`parse_config_file classify_cluster_flags`

function parse_log_file {
    echo `grep '^'$1' ' $songexplorer_model_logdir/${songexplorer_model_replicate}.log | \
	  head -n1 | \
	  cut -d' ' -f3`
}
songexplorer_context=`parse_log_file context`
songexplorer_shiftby=`parse_log_file shiftby`
songexplorer_time_scale=`parse_log_file time_scale`
songexplorer_audio_read_plugin=`parse_log_file audio_read_plugin`
songexplorer_audio_read_plugin_kwargs=`parse_log_file audio_read_plugin_kwargs`
songexplorer_video_read_plugin=`parse_log_file video_read_plugin`
songexplorer_video_read_plugin_kwargs=`parse_log_file video_read_plugin_kwargs`
songexplorer_video_findfile_plugin=`parse_log_file video_findfile_plugin`
songexplorer_video_bkg_frames=`parse_log_file video_bkg_frames`
songexplorer_audio_tic_rate=`parse_log_file audio_tic_rate`
songexplorer_audio_nchannels=`parse_log_file audio_nchannels`
songexplorer_video_frame_rate=`parse_log_file video_frame_rate`
songexplorer_video_frame_height=`parse_log_file video_frame_height`
songexplorer_video_frame_width=`parse_log_file video_frame_width`
songexplorer_video_channels=`parse_log_file video_channels`
songexplorer_deterministic=`parse_log_file deterministic`

classify_parallelize=`grep '^parallelize ' \
                      $songexplorer_model_logdir/${songexplorer_model_replicate}/freeze.ckpt-${songexplorer_model_nsteps}.log | \
                      cut -d' ' -f3`

# set the path to the songexplorer executables
export PATH=$songexplorer_zip_dir/bin:$songexplorer_zip_dir/bin/songexplorer/src:$PATH

# write protect the raw data
chmod -R 755 ${fileshare_dest_dir_prfs}/${wavdir}

# songexplorer v0.8 script to run classify and ethogram on each .wav file in a given folder
dependency=
for wavfile in $(ls ${fileshare_dest_dir_prfs}/${wavdir}/*[^-].WAV) ; do
    [[ "$wavfile" =~ .*(LED1|LED2|SYNC|TMPCH|TMPVAL).WAV ]] && continue

    if [[ ! -f "${wavfile%.WAV}-predicted-1.0pr.csv" ]] ; then
        echo $wavfile
    
        cmd="echo LSB_JOBID=\$LSB_JOBID; \
	     ${songexplorer_zip_dir}/bin/songexplorer/src/classify \
    	     --context=$songexplorer_context \
    	     --shiftby=$songexplorer_shiftby \
    	     --time_scale=$songexplorer_time_scale \
    	     --audio_read_plugin=$songexplorer_audio_read_plugin \
    	     --audio_read_plugin_kwargs=$songexplorer_audio_read_plugin_kwargs \
    	     --video_read_plugin=$songexplorer_video_read_plugin \
    	     --video_read_plugin_kwargs=$songexplorer_video_read_plugin_kwargs \
    	     --video_findfile_plugin=$songexplorer_video_findfile_plugin \
    	     --video_bkg_frames=$songexplorer_video_bkg_frames \
    	     --model=$songexplorer_model_logdir/$songexplorer_model_replicate/frozen-graph.ckpt-${songexplorer_model_nsteps}.pb \
    	     --model_labels=$songexplorer_model_logdir/$songexplorer_model_replicate/labels.txt \
    	     --wav=${wavfile} \
    	     --parallelize=$classify_parallelize \
    	     --audio_tic_rate=$songexplorer_audio_tic_rate \
    	     --audio_nchannels=$songexplorer_audio_nchannels \
    	     --video_frame_rate=$songexplorer_video_frame_rate \
    	     --video_frame_height=$songexplorer_video_frame_height \
    	     --video_frame_width=$songexplorer_video_frame_width \
    	     --video_channels=$songexplorer_video_channels \
    	     --deterministic=$songexplorer_deterministic \
    	     --labels= \
    	     --prevalences= \
	     ; \
             ${songexplorer_zip_dir}/bin/songexplorer/src/ethogram \
    	     $songexplorer_model_logdir \
    	     $songexplorer_model_replicate \
    	     thresholds.ckpt-${songexplorer_model_nsteps}.csv \
    	     ${wavfile} \
	     $songexplorer_audio_tic_rate \
	     False"
        logfile=${wavfile:0:-4}-classify-ethogram.log
        echo $cmd
        echo $cmd >> $logfile
        bsub_stdout=`echo $cmd | bsub ${bsub_flags[@]} -Ne ${=classify_cluster_flags} -o $logfile -e $logfile`
        jobid=`expr match "$bsub_stdout" "$jobid_regex"`
        dependency=${dependency}done\($jobid\)'&&'
    fi
done
dependency=${dependency%&&}

# check the logs for errors
cmd="date; \
     hostname; \
     grep -E '(CUDA_ERROR|No such)' ${fileshare_dest_dir_prfs}/${wavdir}/*.log ; \
     nwav=\`ls ${fileshare_dest_dir_prfs}/${wavdir}/*WAV | wc -l\` ; \
     npred=\`ls ${fileshare_dest_dir_prfs}/${wavdir}/*pred* | wc -l\` ; \
     [[ "\$nwav" == \$(( 5 + \$npred )) ]] || echo ERROR nwav=\$nwav npred=\$npred ; \
     date"
echo $cmd | bsub ${bsub_flags[@]} -w "$dependency" -W 60
