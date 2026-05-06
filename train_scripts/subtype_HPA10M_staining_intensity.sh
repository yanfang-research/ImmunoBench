#!/bin/bash
# Training script for HPA10M staining intensity subtyping task
# This script can be run directly without SLURM

# ==========================================
# Configuration Variables
# ==========================================
# Task configuration
task_name=HPA10M_staining_intensity
modal=ALL
current_prefix="splits712"

# Path configuration - modify these according to your setup
LOG_DIR="logs"
RESULTS_BASE_DIR="results/experiments/train/splits712"

# Create necessary directories
mkdir -p "$LOG_DIR"

# Determine task name with modal suffix
if [ "$modal" == "ALL" ] || [ -z "$modal" ]; then
    task_with_modal="${task_name}"
else
    task_with_modal="${task_name}_${modal}"
fi

# ==========================================
# Data Preparation
# ==========================================
echo "Preparing data splits..."
python re_create_csv.py --task_name $task_name --task_modal $modal
python create_splits_seq.py --test_frac 0.2 --prefix $current_prefix --k 1 --task $task_with_modal --seed 42

# ==========================================
# Model Configuration
# ==========================================
# Specify which backbones to train (modify as needed)
backbones="uni"
# backbones="chief conch conch_v1_5 ctranspath gigapath GPFM phikon uni h_optimus_0 virchow virchow2 chief_wsi titan_wsi gigapath_wsi madeleine_wsi"

# Feature dimensions for each backbone
declare -A in_dim
# Patch-level backbones
in_dim["phikon"]=768
in_dim["chief"]=768
in_dim["conch_v1_5"]=768
in_dim["conch"]=512
in_dim["ctranspath"]=768
in_dim["gigapath"]=1536
in_dim["GPFM"]=1024
in_dim["uni"]=1024
in_dim["virchow"]=2560
in_dim["virchow2"]=2560
in_dim["h_optimus_0"]=1536
# WSI-level backbones
in_dim["chief_wsi"]=768
in_dim["titan_wsi"]=768
in_dim["gigapath_wsi"]=768
in_dim["madeleine_wsi"]=512

# Training parameters
n_classes=4
task=$task_name
seed=1024
preloading="no"
patch_size="512"

# Set up paths
if [ "$modal" == "ALL" ] || [ -z "$modal" ]; then
    root_log="${LOG_DIR}/train_log_${task}_"
    results_dir="${RESULTS_BASE_DIR}/${task}"
else
    root_log="${LOG_DIR}/train_log_${task}_${modal}_"
    results_dir="${RESULTS_BASE_DIR}/${task}_${modal}"
fi
split_dir="$current_prefix/${task_name}_100"

# ==========================================
# GPU Configuration
# ==========================================
GPU_ID=${CUDA_VISIBLE_DEVICES:-0}
echo "Using GPU: $GPU_ID"

# ==========================================
# Training Loop
# ==========================================
echo "Starting training for backbones: $backbones"

for backbone in $backbones
do
    if [[ $backbone == *"wsi"* ]]; then
        model="wsi_mil"
    else
        model="att_mil"
    fi
    exp=$model"/"$backbone

    echo "Training $exp on GPU: $GPU_ID"

    k_start=0
    k_end=-1

    CUDA_VISIBLE_DEVICES=${GPU_ID} python main.py \
        --seed $seed \
        --split_dir $split_dir \
        --drop_out \
        --task_type subtyping \
        --early_stopping \
        --lr 2e-4 \
        --reg 1e-4 \
        --k 1 \
        --k_start $k_start \
        --k_end $k_end \
        --label_frac 1.0 \
        --max_epochs 1 \
        --exp_code $exp \
        --patch_size $patch_size \
        --weighted_sample \
        --task $task_with_modal \
        --backbone $backbone \
        --results_dir $results_dir \
        --model_type $model \
        --log_data \
        --preloading $preloading \
        --n_classes $n_classes \
        --in_dim ${in_dim[$backbone]} > "$root_log""$model"_"$backbone.log" 2>&1

    echo "Completed $exp"
done

echo "All training tasks completed!"
