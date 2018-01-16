#!/bin/bash

# xtcfix.sh
# Gromacs Trajectory Fix
# Originally written in: GNU bash, version 4.1.2(1)-release (x86_64-redhat-linux-gnu)
#
# Description:
# This script will be useful if you have multiple magic numbers and/or core failures in your 
# trajectory due to supercomputer failures/hiccups.
#
# File Preparation:
# 1. Change the "Load Gromacs" section to your own version if needed. 
# 2. Change the prefix and suffix  under the "Version control of gromacs commands" to your own version if needed.
#
# Example:
# ./xtcfix.sh [trajectory] [trajectory out name] [part number (optional)]
# ./xtcfix.sh md.xtc segment.xtc 
#
# Changelog:
#
#
# Written by: Richard Banh on January 16, 2018

# Parameters
filein=$1 # input file 
fileout=$2 # output file 
count=${3:-1} # iteration number for part number (default value: 1)
inputB=0 # Beginning/Start Time (ps) 
inputE=0 # End Time (ps)
recE=0 # recommendation for end frame (approximation)

# Load Gromacs
module load intel64/15.3.187 openmpi/1.10.0_intel15 gromacs64/4.6.7_ompi

# Version control of gromacs commands
pf='' # prefix 
sf='_mpi' # suffix

# Name of temporary directory
D=rescue_temp

# Create temporary working directory
if [ ! -d ${D} ]; then
    mkdir ${D} 
fi 

# Print input info to the console
input_info() {
    echo "Current Time Inputs "
    echo "beginning/start time: $inputB ps"
    echo "end time: $inputE ps (recommended: approx $recE ps)"
    echo ''
}

# Segment Trajectory
re='^[0-9]+([.][0-9]+)?$' # Check for integer + floats 
repeater() {
    echo "Segmenting trajectory: Part $count"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Your output file will be named part$count.$fileout"
    echo ""
    echo "Y (default) will prompt the user for a beginning/start and end time in ps."
    echo "B will prompt the user for a beginning/start time in ps only."
    echo "E will prompt the user for an end time in ps only (uses previously used start time: default 0).
    (use previous beginning/start time entered - default of 0 ps before user input)"
    echo "N will exit the program."
    echo ""
    echo "Options: [Y]/C/B/E/N"

    read input
    input="${input,,}"
    case $input in
      no|n)
          exit # Exit program
      ;;
      e)
          input_info # Current Time Inputs
          # User Input
          echo "Enter End Time (ps):
          (the set beginning/start time will be used - default 0 ps if not entered previously.)"
          read inputE # End Time (ps), uses previously set inputB
          while ! [[ $inputE =~ $re ]]; do
              echo "[End Time] You have not enetered a positive number.
              Please try again."
              read inputE
          done
          # Segment Trajectory
          ${pf}trjconv${sf} -f $filein -o ${D}/part$count.$fileout -b $inputB -e $inputE >& ${D}/temp.txt
      ;;
      b)
          input_info # Current Time Inputs
          # User Input
          echo "Enter Beginning/Start Time (ps):
          (no end time will be used.)"
          read inputB # Beg Time (ps)
          while ! [[ $inputB =~ $re ]]; do
              echo "[Beginning/Start Time] You have not enetered a positive number.
              Please try again."
              read inputB
          done
          # Segment Trajectory
          ${pf}trjconv${sf} -f $filein -o ${D}/part$count.$fileout -b $inputB >& ${D}/temp.txt
          echo ''
      ;;
      yes|y|*)
          input_info # Current Time Inputs
          # User Input
          echo "Enter Beginning/Start Time (ps):"
          read inputB # Beg Time (ps)
          while ! [[ $inputB =~ $re ]]; do
              echo "[Beginning/Start Time] You have not enetered a positive number.
              Please try again."
              read inputB
          done
          echo "Enter End Time (ps):"
          read inputE # End Time (ps)
          while ! [[ $inputE =~ $re ]]; do
              echo "[End Time] You have not enetered a positive number.
              Please try again."
              read inputE
          done
          # Segment Trajectory
          ${pf}trjconv${sf} -f $filein -o ${D}/part$count.$fileout -b $inputB -e $inputE >& ${D}/temp.txt
      ;;
  esac # End of Input Cases
  echo ''

  # Remind user of inputs (0 ps end time means no end time used.)
  input_info # Print current input values

  echo "Output (below):"
  tail -n 10 ${D}/temp.txt
  echo ''

  cat rescue_temp/temp.txt | grep "frame" | tail -n 1 >& ${D}/temp2.txt

  echo "If no random message appears ABOVE, the time range should be ok."
  recE=$(tail ${D}/temp2.txt -n 1 | awk '{print $(NF-1)}')

  # Check if the user is OK with the results
  #######################################################
  echo "Are you OK with the result? If not, the previous file will be removed
  and you will be asked to segment the trajectory again.
  (Note: Previous input values will not reset.)"
  echo "Options: [Y]/N"
  read input
  input="${input,,}"
  case $input in
      n|no)
          rm ${D}/part$count.$fileout
          echo ""
          repeater #recursive element
      ;;
      y|yes|*)
          echo $count $inputB $inputE >> ${D}/userinput.txt
          let count++ # increase count by 1
      ;;
  esac
  echo "Do you wish to continue to the next iteration? Part $count."
  echo "Options: [Y]/N"
  read input
  input="${input,,}"
  case $input in
      n|no)
        echo 'Not continuing segmentation. Time to get your life back together.'
        echo "Would you like to concatenate the segments? (from part 1 to $((count-1)))"
        echo "Options: [Y]/N"

        read inputC
        inputC="${inputC,,}"
        case $inputC in
          no|n)
            echo "The program is exiting."
            exit
          ;;
          yes|y)
            ${pf}trjcat${sf} -f $(seq -f ${D}/part%g.$fileout 1 $((count-1))) -o ${D}/concat.xtc

            exit
          ;;
        esac

      ;;
      y|yes|*)
          repeater
      ;;
  esac
}

repeater
