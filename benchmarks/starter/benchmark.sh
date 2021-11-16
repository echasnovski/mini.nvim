#! /bin/bash

# Perform benchmarking of startup times with different Neovim 'init' files.
# Execute `nvim -u <*> --startuptime <*>` several times (as closely to actual
# usage as possible) in rounds alternating between input 'init' files (to "mix"
# possible random noise). Store output in .csv file with rows containing
# startup times for a single round, columns - for a single 'init' file.

# WARNING: EXECUTION OF THIS SCRIPT LEADS TO FLICKERING OF SCREEN WHICH WHICH
# MAY CAUSE HARM TO YOUR HEALTH. This is because every 'init' file leads to an
# actual opening of Neovim with later automatic closing.

# Number of rounds to perform benchmark
n_rounds=1000

# Path to output .csv file with startup times per round
csv_file=startup-times.csv

# Path to output .md file with summary table
summary_file=startup-summary.md

# 'Init' files ids with actual paths computed as 'init-files/init_*.lua'
init_files=(starter-default empty startify-starter startify-original startify-alpha dashboard-starter dashboard-original dashboard-alpha)

function comma_join { local IFS=","; shift; echo "$*"; }

function benchmark {
  rm -f "$csv_file"
  touch "$csv_file"

  local tmp_bench_file="tmp-bench.txt"
  touch "$tmp_bench_file"

  comma_join -- "$@" >> startup-times.csv

  for i in $(seq 1 $n_rounds); do
    echo "Round $i"

    local bench_times=()

    for init_file in "$@"; do
      nvim -u "init-files/init_$init_file.lua" --startuptime "$tmp_bench_file"
      local b_time=$(tail -n 1 "$tmp_bench_file" | cut -d " " -f1)
      bench_times=("${bench_times[@]}" "$b_time")
    done

    comma_join -- "${bench_times[@]}" >> "$csv_file"

    rm "$tmp_bench_file"
  done
}

benchmark "${init_files[@]}"

# Produce output summary
./make_summary.py "${csv_file}" "${summary_file}"
