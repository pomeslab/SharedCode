#!/bin/bash

# Gromacs Trajectory Fix
# Originally written in:
# GNU bash, version 4.1.2(1)-release (x86_64-redhat-linux-gnu)
# for Gromacs 4.6.7 (newer versions should work with little modification)
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
# ./xtcfix.sh md.xtc product.xtc
#
# When using the program, test for start frames first with (B), then move onto
# end frames with (E). Once you've found the lower and upper bounds, save and
# continue to the next part.
#
# Changelog:
# -- 01/23/2018 -- Richard Banh
# Restructured the code
# Allowed B and E selections to be repeated consecutively.
# Changed some prompts.
# Added integer check for count number.
# Added a reset feature.
#
# -- 01/24/2018 -- Richard Banh
# Included code to output ALL errors to a file and detect any magic number or
#   core dump errors that occur. This is then used to provide the user
#   recommendations on the next step.
# Added autorun function (provide timestep length and final end time)
#
# -- 01/30/2018 -- Richard Banh
# Added specific parameters to the script. Only required parameter is traj input.
# Added an option to add a log file to extract the last end time and feed it
#   to the automatic segmenter (A).
# Removed some redundant code.
#
# Written by: Richard Banh on January 16, 2018

# Load Gromacs
module load intel64/15.3.187 openmpi/1.10.0_intel15 gromacs64/4.6.7_ompi

# Version control of gromacs commands
pf='' # prefix
sf='_mpi' # suffix

# Set up parameters for the script
PROGNAME=$0
usage() {
  cat << EOF >&2
Usage: $PROGNAME [-f <file>]
Example: ./$PROGNAME trajectory.xtc

-f <file>          :... (req) input trajectory file
-o <file>          :... (opt) output trajectory file
-n <integer>       :... (opt) part number
-l <file>          :... (opt) log file (auto extract last time)
-x <integer float> :... (opt) time for 1 time step in picoseconds (ps)
-d <dir>           :... (opt) directory for output files
EOF
  exit 1
}

# Default Parameters
filein=false # input file (required)
fileout=trajectory.xtc # output file (optional)
count=1 # iteration number for part number (optional))
logfile=false # log file input (optional)
inputTS=false # time for 1 time step (ps)
D=XTCFIX # subdirectory for output files (optional)

# Search for command line arguments
while getopts f:o:n:l:x:d: o; do
  case $o in
    (f) filein=$OPTARG;;
    (o) fileout=$OPTARG;;
    (n) count=$OPTARG;;
    (l) logfile=$OPTARG;;
    (x) inputTS=$OPTARG;;
    (d) D=$OPTARG;;
    (*) usage ;;
  esac
done

# Other Variables
inputB=0 # Beginning/Start Time (ps)
inputE=0 # End Time (ps)
recE=0 # recommendation for end frame (approximation)
numError=0 # starting value of the number of errors detected

# Check for input trajectory file; exit if not found
if [ $filein == false ]; then
  echo "error: No [input trajectory] provided. (-f)"
  usage
fi

# Check that the variable "count" is an integer
re='^[0-9]+$'
if ! [[ $count =~ $re ]] ; then
  echo "error: The [part number] provided is not an integer. (-n)"
  exit
fi

# Check that the variable "inputTS" is a number if it has been provided.
if [ $inputTS != false ]; then
  re='^[0-9]+([.][0-9]+)?$'
  if ! [[ $inputTS =~ $re ]] ; then
    echo "error: The [time step] provided is not an integer. (-x)"
    exit
  fi
fi

# Find the time of the last frame recorded in the log file if provided.
if [ $logfile != false ]; then
  array=($(tail $logfile -n 200 | grep "Step.*Time.*Lambda" -A 1))
  # STEP (len-3), TIME (len-2), LAMBDA (len-1)
  inputET=${array[${#array[@]}-2]}
fi

# Create temporary working directory
if [ ! -d ${D} ]; then
  mkdir ${D}
fi

# Check for integer + floats (-b and -e inputs)
re='^[0-9]+([.][0-9]+)?$'

# Print input info to the console
inputInfo() {
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
  inputInfo
  echo "
  Input            : $filein
  Output (part)    : part$count.$fileout
  Output (combined): $fileout

  Option : Description
  ------------------------------------------------------------------------------
  A            : auto make all parts using valid times, concatenate, then exit
  B            : (-b) enter beginning/start time in ps only. No end time (-e) used.
  E            : (-e) enter end time in ps only (uses start time: $inputB ps).
  BE           : (-b, -e) quickly enter beginning/start and end times in ps. & No trjconv.
  S            : save the part as part$count.$fileout with (-b $inputB -e $inputE) & proceed to the next part.
  C            : concatenate all parts (parts 1 to $((count-1))). Save as $fileout
  R/Reset      : reset back to part 1 and delete old files created.
  Q/Exit/Quit  : exit the program.

  Please select an option.
  "
  read input
  input="${input,,}"
  case $input in
    a) echo ''
      autoRun
    ;;
    b) echo ''
      codeB
    ;;
    e) echo ''
      codeE
    ;;
    be) echo ''
      # Current Time Inputs
      inputInfo
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
      savePart

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
      # Concatenate the parts
      concatParts
      homeMenu
    ;;
    q|exit|quit) echo ''
      echo "Exiting the program. Good day to you too."
      exit
    ;;
    r|reset) echo ''
      resetFix
      homeMenu
    ;;
    *) echo ''
      echo "You have not entered in a valid option. Returning home."
      homeMenu
    ;;
  esac
}

resetFix() {
  echo "Deleting files and reseting to Part 1"
  rm -r ${D}
  mkdir ${D}
  count=1
}

taskMain() {
  # Current Time inputs
  inputInfo

  # Run task (trjconv + recommender)
  taskRun

  # Check for Errors (+delete temporary files)
  errorCheck

  # Ask user if they wish to redo the task
  echo "Do you wish to redo this task?"
  echo "Options: [Y]/N"
  read input
  input="${input,,}"
  case $input in
    n|no)
      echo "Returning to the home menu."
      printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
      echo ""
      homeMenu
    ;;
    y|yes|*)
      # Run the function provided as a parameter to this function
      $1
    ;;
    esac
}

codeB() {
  # Current Time inputs
  inputInfo

  # User Input
  echo "Enter Beginning/Start Time (ps): (no end time will be used.)"
  read inputB
  while ! [[ $inputB =~ $re ]]; do
      echo "[Beginning/Start Time] You have not enetered a positive number.
      Please try again."
      read inputB
  done

  # Segment Trajectory
  PARAMETERS="-b $inputB"

  # Information on the trjconv task performed (pass function name for repeat)
  taskMain ${FUNCNAME[0]}
}

codeE() {
  # Current Time inputs
  inputInfo

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
  taskMain ${FUNCNAME[0]}
}

errorCheck() {
  # Count the number of errors
  echo "Calculating errors ...
  (looking for [core dumped, floating point exception, fatal error, magic number])
  "
  numError=$(cat ${D}/temp1.txt | grep -i "floating point exception\|core dumped\|fatal error\|magic number" | wc -l)
  if [ $numError -gt 0 ]; then
    echo "Caution! Errors detected. It is recommended you check your time inputs."
    #echo "
    #Error Identifier         | Frequency
    #----------------------------------------------
    #Floating Point Exception | $(cat ${D}/temp1.txt | grep -i "floating point exception" | wc -l)
    #Core Dumped              | $(cat ${D}/temp1.txt | grep -i "core dumped" | wc -l)
    #Fatal Error              | $(cat ${D}/temp1.txt | grep -i "fatal error" | wc -l)
    #Magic Number             | $(cat ${D}/temp1.txt | grep -i "magic number" | wc -l)
    #"
  else
    echo "No errors detected with this time range."
  fi
  echo ''

  # Remove temporary files
  rm ${D}/temp1.txt ${D}/temp2.txt

  # Remove file (only when user saves(S) is the file kept)
  if [ -e ${D}/part$count.$fileout ]; then
    rm ${D}/part$count.$fileout
  fi
}

savePart() {
  # Save Trajectory (output to terminal)
  ${pf}trjconv${sf} -f $filein -o ${D}/part$count.$fileout -b $inputB -e $inputE
}

concatParts() {
  echo ''
  echo "Time to get your life back together. Con-cat-innate it!"
  echo ''
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "File / Beginning Time (ps) / End Time (ps)"
  cat ${D}/userinput.txt | column -t
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  echo "Would you like to concatenate all parts? (from part 1 to $((count-1)))."
  echo "Options: [Y]/N"
  read input
  input="${input,,}"
  case $input in
    no|n)
      echo "Fine. I'm in pieces. Why bother breaking my heart by asking."
    ;;
    yes|y|*)
      echo "Fuuu...siooonn. Ha!"
      ${pf}trjcat${sf} -f $(seq -f ${D}/part%g.$fileout 1 $((count-1))) -o ${D}/$fileout
    ;;
  esac
}

taskRun() {
  # Output of the chosen task
  echo ""
  bash -c "${pf}trjconv${sf} -f $filein -o ${D}/part$count.$fileout $PARAMETERS; true" >& ${D}/temp 2> ${D}/temp1.txt
  rm ${D}/temp
  echo "Output: end of file (below):"
  echo "----------------------------"
  tail -n 10 ${D}/temp1.txt
  echo ''
  cat ${D}/temp1.txt | grep "frame" | tail -n 1 >& ${D}/temp2.txt
  echo ''

  # Calculate recommended end time based on results

  IFS=' ' read -r -a array <<< $(cat ${D}/temp2.txt -A)
  #recE=$(tail ${D}/temp2.txt -n 1 | awk '{print $(NF-1)}')
  for i in $(seq ${#array[@]} -1 0); do
    if [ ${array[$i]} == 'time' ]; then
      recE=${array[$(( i + 1 ))]}
      break
    fi
  done 2> /dev/null
}

autoRun() {
  # Reset Fix directory (count=1, no files)
  resetFix

  # 0. Ask user for timestep (integer) and true end time
  inputB=0
  inputE=0
  numError=1

  if [ $inputTS == false ]; then
    echo "Enter the length of one timestep (ps):"
    read inputTS
    while ! [[ $inputTS =~ $re ]]; do
        echo "[Timestep] You have not enetered a positive number.
        Please try again."
        read inputTS
    done
  else
    echo "The time step enetered as a parameter will be used:      $inputTS ps."
  fi

  if [ $logfile == false ]; then
    echo "Enter The Final End Time (ps):"
    read inputET
    while ! [[ $inputET =~ $re ]]; do
        echo "[Final End Time] You have not enetered a positive number.
        Please try again."
        read inputET
    done
  else
    echo "The final end time provided by the log file will be used: $inputET ps"
  fi

  # WHILE END TIME IS LESS THAN USER TRUE END TIME
  while [ $(echo "$inputE < $inputET" | bc) -eq 1 ] ; do
    # Look for no errors for start time
    while ! [ $numError -eq 0 ]; do
      # Check valid B (using +ts)
      PARAMETERS="-b $inputB -e $(echo $inputB + $inputTS | bc)"
      taskRun &> /dev/null # updates recE variable
      errorCheck &> /dev/null # updates numError variable
      if [ $numError -eq 0 ]; then
        PARAMETERS="-b $inputB"
        taskRun &> /dev/null # obtain recommended end time
        inputE=$recE # set end time to recommended value
        rm ${D}/part$count.$fileout ${D}/temp1.txt ${D}/temp2.txt
      else
        # Update start time by adding user provided timestep
        inputB=$(echo $inputB + $inputTS | bc)
      fi
    done

    # Look for errors for end time (as long as end time is less than final end)
    while [ $numError -eq 0 ] && [ $(echo "$inputE < $inputET" | bc) -eq 1 ]; do
      # Check valid E (using +ts)
      PARAMETERS="-b $(echo $inputE - $inputTS | bc) -e $inputE"
      taskRun &> /dev/null # updates recE variable + obtain output files
      errorCheck &> /dev/null # updates numError variable
      if [ $numError -eq 0 ]; then
        # Update end time by adding user provided timestep
        inputE=$(echo $inputE + $inputTS | bc)
      else
        # Go back one timestep to an end time that worked without errors.
        inputE=$(echo $inputE - $inputTS | bc)
      fi
    done

    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    inputInfo
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    if [ $(echo "$inputB < $inputET" | bc) -eq 1 ]; then
      # Save this part using solved start and end times
      savePart
      echo part$count.$fileout $inputB $inputE >> ${D}/userinput.txt
      # Add one to count for the next part
      let count++
      # Set start time to end time + timestep
      inputB=$(echo $inputE + $inputTS | bc)
    fi
  done

  # Concatenate Parts and Return to Home Menu after input
  echo Y | concatParts

  # Return Home
  exit
}

homeMenu
