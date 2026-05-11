#!/bin/bash
# Training script for HNSCC mIF/mIHC CD8 patch-level classification
# This script can be run directly without SLURM

# ==========================================
# Configuration Variables...
# ==========================================
task_name=HNSCC_mIF_mIHC_CD8

LOG_DIR="logs"
RESULTS_BASE_DIR="results/experiments/train/patch"
FEATURES_BASE_DIR="features"

mkdir -p "$LOG_DIR"

backbones="virchow virchow2"
# backbones="chief"

root_log="${LOG_DIR}/train_log_${task_name}_"

# ==========================================
# GPU Configuration
# ==========================================
GPU_ID=${CUDA_VISIBLE_DEVICES:-0}
echo "Using GPU: $GPU_ID"

# ==========================================
# Training Loop
# ==========================================
echo "Starting patch-level training for backbones: $backbones"

for backbone in $backbones
do
    pt_path="${FEATURES_BASE_DIR}/${task_name}/pt_files/${backbone}/feat.pt"
    save_dir="${RESULTS_BASE_DIR}/${task_name}/MLP/${backbone}/"
    out_csv="${save_dir}summary.csv"

    echo "Training ${backbone} on GPU: $GPU_ID"

    CUDA_VISIBLE_DEVICES=${GPU_ID} python train_patch.py \
        --pt_path "$pt_path" \
        --out_csv "$out_csv" \
        --save_path "$save_dir" > "${root_log}${backbone}.log" 2>&1

    echo "Completed ${backbone}"
done

echo "All patch-level training tasks completed!"
