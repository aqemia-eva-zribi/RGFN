SESSION=rgfn
RGFN_DIR=/home/coder/internship/platform-research/molecular_generative_flow_networks/RGFN
LOGDIR=$RGFN_DIR/logs
mkdir -p "$LOGDIR"
STAMP=$(date +%Y%m%d_%H%M%S)
NB_IT=100
OUTLOG="$LOGDIR/run_${NB_IT}_it_${STAMP}.log"
MEMLOG="$LOGDIR/mem_${NB_IT}_it_${STAMP}.log"
GPULOG="$LOGDIR/gpu_${NB_IT}_it_${STAMP}.log"

# Top pane: sync + train, stdout+stderr → log (and visible live)
tmux new-session -d -s "$SESSION" -n main -c "$RGFN_DIR" "
  { echo '=== $(date) starting with n_iterations=100 (20mn) ==='; \
    uv sync --extra cu124 && \
    uv run python train.py --cfg configs/rgfn_seh_proxy.gin; \
    echo \"=== exit=\$? at \$(date) ===\"; \
  } 2>&1 | tee '$OUTLOG'; exec bash"

# Bottom-left pane: system + per-process RSS every 5s
tmux split-window -v -t "$SESSION:main" "
  while true; do
    ts=\$(date '+%F %T')
    free -m | awk -v ts=\"\$ts\" '/Mem:/ {printf \"%s  sys  used=%sMB  avail=%sMB\n\", ts, \$3, \$7}'
    ps -eo pid,rss,comm --sort=-rss --no-headers | head -3 | \
      awk -v ts=\"\$ts\" '{printf \"%s  proc pid=%s rss=%.0fMB %s\n\", ts, \$1, \$2/1024, \$3}'
    sleep 5
  done | tee '$MEMLOG'"

# Bottom-right pane: GPU memory (drop this split if no GPU)
tmux split-window -h -t "$SESSION:main" "
  nvidia-smi --query-gpu=timestamp,memory.used,memory.total,utilization.gpu \
             --format=csv -l 5 | tee '$GPULOG'"

tmux select-layout -t "$SESSION:main" tiled
tmux attach -t "$SESSION"
