# Gromacs Trajectory Fix

## Originally written in:
GNU bash, version 4.1.2(1)-release (x86_64-redhat-linux-gnu) for Gromacs 4.6.7 (newer versions should work with little modification)

## Description:
Gromacs Wrapper for fixing a corrupt trajectories using trjconv. This script will be useful if you have multiple magic numbers and/or core failures in your trajectory due to supercomputer failures/hiccups.

## File Preparation:
1. Change the "Load Gromacs" section to your own version if needed.
2. Change the prefix and suffix  under the "Version control of gromacs commands" to your own version if needed.

```
# Load Gromacs (load own version)
module load intel64/15.3.187 openmpi/1.10.0_intel15 gromacs64/4.6.7_ompi

# Version control of gromacs commands
pf='' # prefix (e.g. gmx, gmx_mpi, etc...)
sf='_mpi' # suffix (e.g. _s, _mpi, etc...)
```

## Example:
```
./xtcfix.sh

Usage: /home/banhrich/xtcfix.sh [-f <file>]
Example: .//home/banhrich/xtcfix.sh trajectory.xtc

-f <file>          :... (req) input trajectory file
-o <file>          :... (opt) output trajectory file
-n <integer>       :... (opt) part number
-l <file>          :... (opt) log file (auto extract last time)
-x <integer float> :... (opt) time for 1 time step in picoseconds (ps)
-d <dir>           :... (opt) directory for output files

./xtcfix.sh md.xtc product.xtc

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

```
When using the program, test for start frames first with (B), then move onto end frames with (E). Once you've found the lower and upper bounds, save and continue to the next part.

**Update!!** Alternatively, you may use option (A) to automate this process.

## Changelog:
-- 01/23/2018 --
1. Restructured the code.
2. Allowed B and E selections to be repeated consecutively.
3. Changed some prompts.
4. Added integer check for count number.
5. Added a reset feature.

-- 01/24/2018 --
1. Included code to output ALL errors to a file and detect any magic number or core dump errors that occur. This is then used to provide the user recommendations on the next step.
2. Added auto-run function (provide time step length and final end time)

-- 01/30/2018 --
1. Added specific parameters to the script. Only required parameter is a trajectory file (-f).
2. Added an option to add a log file to extract the last end time and feed it to the auto-run function (A).
3. Removed some redundant code.

#### Written by: Richard Banh on January 16, 2018
