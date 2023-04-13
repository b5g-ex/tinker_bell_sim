#!/bin/bash
for t in {0..9}; do
    TASK_SEED=$RANDOM;
    for e in {0..9}; do
      ENGINE_SEED=$RANDOM;
      ./tinker_bell_sim $TASK_SEED $ENGINE_SEED 100
    done
done