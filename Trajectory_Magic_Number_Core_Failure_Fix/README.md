# Gromacs Trajectory Fix

## Originally written in:
GNU bash, version 4.1.2(1)-release (x86_64-redhat-linux-gnu) for Gromacs 4.6.7 (newer versions should work with little modification)

## Description:
Gromacs Wrapper for fixing a corrupt trajectories using trjconv. This script will be useful if you have multiple magic numbers and/or core failures in your trajectory due to supercomputer failures/hiccups.

## File Preparation:
1. Change the "Load Gromacs" section to your own version if needed.
2. Change the prefix and suffix  under the "Version control of gromacs commands" to your own version if needed.

## Example:
```
./xtcfix.sh [trajectory] [trajectory out name] [part number (optional)]
./xtcfix.sh md.xtc product.xtc
```

When using the program, test for start frames first with (B), then move onto end frames with (E). Once you've found the lower and upper bounds, save and continue to the next part.

## Changelog:
-- 01/23/2018 --

Restructured the code.

Allowed B and E selections to be repeated consecutively.

Changed some prompts.

Added integer check for count number.

Added a reset feature.

#### Written by: Richard Banh on January 16, 2018
