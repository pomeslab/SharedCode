#! /usr/bin/env python

import os
import subprocess
import StringIO
from optparse import OptionParser

def main(stdoutdata, stderrdata, returncode, accounts):
    if returncode != 0 or stderrdata != '':
        raise IOError('Check the returncode: {0:d}\n and stderrdata: {1!s}\n'.format(
                returncode, stderrdata))

    output = StringIO.StringIO(stdoutdata)

    ll = output.readline()
    while not ll.startswith('active jobs'):
        ll = output.readline()

    acu = {}                                                # active_cores_usage
    while not ll.startswith('eligible jobs'):
        ll, acu = collect_data(output, acu)

    ecu = {}                                              # eligible_cores_usage
    while not ll.startswith('blocked jobs'):
        ll, ecu = collect_data(output, ecu)

    bcu = {}                                               # blocked_cores_usage
    while ll:
        ll, bcu = collect_data(output, bcu)

    if OPTIONS.bn:
        for cores_usage in [acu, ecu, bcu]:
            for k in cores_usage:
                cores_usage[k] /= 8
    return acu, ecu, bcu

def run_showq():
    pipe = subprocess.PIPE
    p = subprocess.Popen('showq', stdout=pipe, stderr=pipe)
    stdoutdata, stderrdata = p.communicate()
    return stdoutdata, stderrdata, p.returncode

def collect_data(output, cores_usage):
    ll = output.readline()
    sl = ll.split()
    if len(sl) == 9:
        user = sl[1]
        if user in accounts:
            ncore = int(sl[3])
            check1 = (not OPTIONS.ib) and (not OPTIONS.gg)
            check2 = OPTIONS.gg and ncore == 8
            check3 = OPTIONS.ib and ncore > 8
            if check1 or check2 or check3:
                n = ncore
            else:
                n = 0
            if user in cores_usage:
                cores_usage[user] += n
            else:
                cores_usage[user] = n
    return ll, cores_usage

def parse_cmd():
    parser = OptionParser()
    parser.add_option('--gg', action='store_true', dest='gg', default=False,
                      help='show the number of GigE cores only')
    parser.add_option('--ib', action='store_true', dest='ib', default=False,
                      help='show the number of ib cores only') 
    parser.add_option('-n', '--by-node', action='store_true', dest='bn', default=False,
                      help='show the number of nodes instead of cores') 
    global OPTIONS
    OPTIONS, args = parser.parse_args()

if __name__ == "__main__":
    parse_cmd()
    accounts = os.listdir('/scratch/p/pomes')
    stdoutdata, stderrdata, returncode = run_showq()
    acu, ecu, bcu = main(stdoutdata, stderrdata, returncode, accounts)
    total_usage = {}
    for a in accounts:
        total_usage[a] = acu.get(a, 0) + ecu.get(a, 0) + bcu.get(a, 0)

    print "{0:10s} {1:8s} {2:8s} {3:8s} {4:8s}\n{5:44s}".format(
        'USERNAME', 'ACTIVE', 'ELIGIBLE', 'BLOCKED', 'TOTAL', "=" * 44)

    sorted_keys = reversed(sorted(total_usage, key=total_usage.get))
    for k in sorted_keys:
        print "{0:10s} {1:<8d} {2:<8d} {3:<8d} {4:<8d}".format(
            k, acu.get(k, 0), ecu.get(k, 0), bcu.get(k, 0), total_usage[k])
