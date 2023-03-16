#!/bin/env python3

import re
import sys
import os

if len(sys.argv) > 1:
    src_file = sys.argv[1]
else:
    print("You must provide a source file as first argument", file=sys.stderr)
    sys.exit(1)

if not os.access(src_file, os.R_OK):
    print(src_file, "is not readable", file=sys.stderr)
    sys.exit(2)

pattern = re.compile('^(?P<type>deb|deb-src) +(?P<options>\[.+\] ?)*(?P<uri>\w+:\/\/\S+) +(?P<suite>\S+)(?: +(?P<components>.*))?$')

sources = {}

def split_options(raw):
    table = str.maketrans({
        "[": None,
        "]": None
    })
    options = raw.translate(table).split(' ')

    return options

with open(src_file,'r') as file:
    for line in file:
        matches = re.match(pattern, line)
        if matches is not None:
            # print(matches.groupdict())
            uri = matches['uri']

            options = {}
            if matches.group('options'):
                for option in split_options(matches['options']):
                    if "=" in option:
                        key, value = option.split("=")
                        options[key] = value

            if uri in sources:
                sources[uri]["Types"].add(matches["type"])
                sources[uri]["URIs"] = matches["uri"]
                sources[uri]["Suites"].add(matches["suite"])
                sources[uri]["Components"].update(matches["components"].split(' '))
            else:
                source = {
                    "Types": {matches['type']},
                    "URIs": matches['uri'],
                    "Enabled": "yes",
                }

                if matches.group('suite'):
                    source["Suites"] = set(matches['suite'].split(' '))

                if matches.group('components'):
                    source["Components"] = set(matches['components'].split(' '))

                if "arch" in options:
                    if "Architectures" in source:
                        source["Architectures"].append(options["arch"])
                    else:
                        source["Architectures"] = {options["arch"]}

                if "signed-by" in options:
                    if "Signed-by" in source:
                        source["Signed-by"].append(options["signed-by"])
                    else:
                        source["Signed-by"] = {options["signed-by"]}

                if "lang" in options:
                    if "Languages" in source:
                        source["Languages"].append(options["lang"])
                    else:
                        source["Languages"] = {options["lang"]}

                if "target" in options:
                    if "Targets" in source:
                        source["Targets"].append(options["target"])
                    else:
                        source["Targets"] = {options["target"]}

                sources[uri] = source

for i, (uri, source) in enumerate(sources.items()):
    if i > 0:
        print("")
    for key, value in source.items():
        if isinstance(value, str):
            print("{}: {}".format(key, value) )
        else:
            print("{}: {}".format(key, ' '.join(value)) )
    i += 1