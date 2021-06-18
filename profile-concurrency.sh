#!/bin/bash
#SBATCH --nodes=1              # Number of nodes
#SBATCH --ntasks-per-node=1    # Number of MPI ranks per node
#SBATCH --ntasks-per-socket=1  # Number of MPI ranks per socket
#SBATCH --cpus-per-task=2      # Number of HW threads per task
#SBATCH --gres=gpu:1           # Number of requested gpus per node, can vary between 1 and 4
#SBATCH --mem=10000MB          # Memory per node
#SBATCH --time 00:45:00        # Walltime, format: HH:MM:SS
#SBATCH --mem-bind=local
#SBATCH -A tra21_hackathon
#SBATCH -p m100_usr_prod
#SBATCH --qos=m100_qos_dbg     # for higher priority, max 2 hours 2 nodes
#SBATCH --exclusive            # Request node exclusive to avoid coliding with other nsys users on same node
#SBATCH -e job.%J.err
#SBATCH -o job.%J.out

#export TMPDIR=$CINECA_SCRATCH/tmp 
#mkdir -p $CINECA_SCRATCH/tmp
rm -rf /tmp/nvidia
ln -s $TMPDIR /tmp/nvidia
module load cuda/11.0
module load hpc-sdk/2021--binary

cd build/bin/linux-x64/Release

# concurrency-msg
nsys profile --force-overwrite true -o concurrency-msg-v100 ./concurrency-msg  -s 1 -r 12
# ncu --set full --force-overwrite -o ./concurrency-msg-v100 ./concurrency-msg -s 1 -r 12

# concurrency-msg-birth-death
nsys profile --force-overwrite true -o concurrency-msg-birth-death-v100 ./concurrency-msg-birth-death  -s 1 -r 12
# ncu --set full --force-overwrite -o ./concurrency-msg-birth-death-v100 ./concurrency-msg-birth-death -s 1 -r 12

rm -rf /tmp/nvidia

# Run this script with sbatch profile-concurrency.sh