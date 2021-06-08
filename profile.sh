#!/bin/bash
#SBATCH --nodes=1              # Number of nodes
#SBATCH --ntasks-per-node=1    # Number of MPI ranks per node
#SBATCH --ntasks-per-socket=1  # Number of MPI ranks per socket
#SBATCH --cpus-per-task=2      # Number of HW threads per task
#SBATCH --gres=gpu:1           # Number of requested gpus per node, can vary between 1 and 4
#SBATCH --mem=10000MB          # Memory per node
#SBATCH --time 00:30:00        # Walltime, format: HH:MM:SS
#SBATCH --mem-bind=local
#SBATCH -A tra21_hackathon
#SBATCH -p m100_usr_prod
#SBATCH --qos=m100_qos_dbg     # for higher priority, max 2 hours 2 nodes
#SBATCH -e job.%J.err
#SBATCH -o job.%J.out

export TMPDIR=$CINECA_SCRATCH/tmp-$user 
mkdir -j $CINECA_SCRATCH/tmp-$user
module load cuda/11.0

cd build/bin/linux-x64/Release

#fgpu2
nsys profile -o f2-boids-s3d-82k-s5 boids_spatial3D -s 5 -d 2
ncu --set full -o f2-boids-s3d-82k-s5 boids_spatial3D -s 5 -d 2

#fgpu2 rtc
nsys profile -o f2-boids-rtc-s3d-82k-s5 boids_rtc_spatial3D -s 5 -d 2
ncu --set full -o f2-boids-rtc-s3d-82k-s5 boids_rtc_spatial3D -s 5 -d 2

# Run this script with srun profile.sh