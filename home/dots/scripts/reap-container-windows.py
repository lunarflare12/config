#!/usr/bin/env python3
import os
import sys

script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "aurora")
os.execv(script, [script, "reaper", *sys.argv[1:]])
