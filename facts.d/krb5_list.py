#!/usr/bin/env python

from __future__ import print_function

import subprocess
import os
import re
import json

p = subprocess.Popen(
    'klist -k',
    stdout=subprocess.PIPE,
    stderr=open(os.devnull,'w'),
    shell=True
)

pat = '\s+(\d+)\s+(\w+/\S+@\S+)'
klist = dict()
for line in p.stdout:
    m = re.search(pat, line)
    if m:
        kvno = int(m.group(1))
        entry = m.group(2)
        if kvno not in klist:
            klist[kvno] = []
        klist[kvno].append(entry)
if klist:
    print("klist={0}".format(json.dumps(klist)))
