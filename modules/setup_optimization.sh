#!/usr/bin/env bash

function setup_perf() {
    echo "Setting up Optimization..."

    sudo pacman -S scx-scheds bpf llvm tuned -y

    sudo systemctl enable \
      scx.service \
      scx_loader.service

    cat > "/etc/scx_loader.toml" << EOF
default_sched = "scx_bpfland"
default_mode = "Auto"
EOF

    echo "Optimization setup complete."
}

export -f setup_perf
