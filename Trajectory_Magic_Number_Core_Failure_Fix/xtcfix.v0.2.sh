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
fileout=${2:-trajectory.xtc} # output file
count=${3:-1} # iteration number for part number (default value: 1)
if ! [[ $count =~ $re ]]; then
  "Part Number must be an integer "
inputB=0 # Beginning/Start Time (ps)
inputE=0 # End Time (ps)
recE=0 # recommendation for end frame (approximation)
inputTemp=B

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


# Check for integer + floats
re='^[0-9]+([.][0-9]+)?$'

# Print input info to the console
input_info() {
  echo "
  Current Time Inputs
    (-b) beginning/start time: $inputB ps
    (-e) end time:             $inputE ps (recommended: approx $recE ps)"
  echo ''
}

# Main function (home menu)
homeMenu() {
  echo ""
  echo "Segmenting trajectory: Part $count"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  input_info
  echo "
  Input:  $filein
  Output (part): part$count.$fileout
  Output (combined): $fileout

  Option : Description
  ------------------------------------------------------------------------------
  B      : (-b) enter beginning/start time in ps only. No end time (-e) used.
  E      : (-e) enter end time in ps only (uses start time: $inputB ps).
  BE     : (-b, -e) quickly enter beginning/start and end times in ps. & No trjconv.
  S      : save the part as part$count.$fileout with (-b $inputB -e $inputE) & proceed to the next part.
  C      : concatenate all parts (parts 1 to $((count-1))). Save as $fileout
  Reset  : reset back to part 1 and delete old files created.
  Exit   : exit the program.

  Please select an option.
  "
  read input
  input="${input,,}"
  case $input in
    b) echo ''
      codeB
    ;;
    e) echo ''
      codeE
    ;;
    be) echo ''
      # Current Time Inputs
      input_info
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

      # Return to the home menu
      homeMenu
    ;;
    s) echo ''
      # Save Trajectory (output to terminal)
      ${pf}trjconv${sf} -f $filein -o ${D}/part$count.$fileout -b $inputB -e $inputE
      echo "Proceed to Part $((count+1))? Options: [Y]/N"
      read input
      input="${input,,}"
      case $input in
          n|no)
            rm ${D}/part$count.$fileout
            echo "Staying on Part $count. Returning to home menu."
            homeMenu
          ;;
          y|yes|*)
              echo part$count.$fileout $inputB $inputE >> ${D}/userinput.txt
              let count++ # increase count by 1
              echo "Going forward to Part $count. Returning to home menu."
              homeMenu
          ;;
      esac
    ;;
    c) echo ''
      echo "Time to get your life back together. Con-cat-innate it!"

      echo "File / Beginning Time (ps) / End Time (ps)"
      cat ${D}/userinput.txt | column -t

      echo "
Would you like to concatenate all parts? (from part 1 to $((count-1))).
Options: [Y]/N
      "
      read inputC
      inputC="${inputC,,}"
      case $inputC in
        no|n)
          echo "Fine. I'm in pieces. Returning home."
          homeMenu
        ;;
        yes|y|*)
          ${pf}trjcat${sf} -f $(seq -f ${D}/part%g.$fileout 1 $((count-1))) -o ${D}/$fileout.xtc
          echo "Life never looked brighter. Returning home."
          homeMenu
        ;;
      esac
    ;;
    exit) echo ''
      echo "Exiting the program. Good day to you too."
      exit
    ;;
    reset) echo ''
      echo "Deleting files and reseting to Part 1"
      rm -r ${D}
      mkdir ${D}
      count=1
      homeMenu
    ;;
    *) echo ''
    echo "You have not entered in a valid option. Returning home."
    homeMenu
  esac
}

taskRun() {
  # Current Time inputs
  input_info

  # Output of the chosen task
  echo ""
  echo "Output 1/2 (below):"
  ${pf}trjconv${sf} -f $filein -o ${D}/part$count.$fileout $PARAMETERS  >& ${D}/temp.txt

  echo "Output 2/2: end of file (below):"
  tail -n 10 ${D}/temp.txt
  echo ''
  cat rescue_temp/temp.txt | grep "frame" | tail -n 1 >& ${D}/temp2.txt
  echo "If no random message appears ABOVE, the time range should be ok."
  recE=$(tail ${D}/temp2.txt -n 1 | awk '{print $(NF-1)}')

  # Ask user if they wish to redo the task
  echo "Do you wish to redo this task?"
  echo "Options: [Y]/N"
  read input
  input="${input,,}"
  case $input in
      n|no)
        rm ${D}/part$count.$fileout
        echo "Returning to the home menu."
        printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
        echo ""
        homeMenu
      ;;
      y|yes|*)
        rm ${D}/part$count.$fileout
        # Run the function provided as a parameter to this function
        $1
      ;;
    esac
}

codeB() {
  # Current Time inputs
  input_info

  # User Input
  echo "Enter Beginning/Start Time (ps): (no end time will be used.)"
  read inputB # Beg Time (ps)
  while ! [[ $inputB =~ $re ]]; do
      echo "[Beginning/Start Time] You have not enetered a positive number.
      Please try again."
      read inputB
  done

  # Segment Trajectory
  PARAMETERS="-b $inputB"

  # Information on the trjconv task performed (pass function name for repeat)
  taskRun ${FUNCNAME[0]}
}

codeE() {
  # Current Time inputs
  input_info

  # User Input
  echo "Enter End Time (ps): (set beginning time of $inputB ps will be used.)"
  read inputE
  while ! [[ $inputE =~ $re ]]; do
      echo "[End Time] You have not enetered a positive number.
      Please try again."
      read inputE
  done

  # Segment Trajectory (use previously set -b)
  PARAMETERS="-b $inputB -e $inputE"

  # Information on the trjconv task performed (pass function name for repeat)
  taskRun ${FUNCNAME[0]}
}

homeMenu
