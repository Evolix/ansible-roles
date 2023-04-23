#!/bin/env python3

import re
import sys
import os
import select
import apt
import apt_pkg

# Order matters !
destinations = {
    "debian-security": "security.sources",
    ".*-backports": "backports.sources",
    ".debian.org": "system.sources",
    "mirror.evolix.org": "system.sources",
    "pub.evolix.net": "evolix_public_old.sources",
    "pub.evolix.org": "evolix_public.sources",
    "artifacts.elastic.co": "elastic.sources",
    "download.docker.com": "docker.sources",
    "downloads.linux.hpe.com": "hp.sources",
    "pkg.jenkins-ci.org": "jenkins.sources",
    "packages.sury.org": "sury.sources",
    "repo.mongodb.org": "mongodb.sources",
    "apt.newrelic.com": "newrelic.sources",
    "deb.nodesource.com": "nodesource.sources",
    "dl.yarnpkg.com": "yarn.sources",
    "apt.postgresql.org": "postgresql.sources",
    "packages.microsoft.com/repos/vscode": "microsoft-vscode.sources",
    "packages.microsoft.com/repos/ms-teams": "microsoft-teams.sources",
    "updates.signal.org": "signal.sources",
    "downloads.1password.com/linux/debian": "1password.sources",
    "download.virtualbox.org": "virtualbox.sources"
}

sources_parts = apt_pkg.config.find_dir('Dir::Etc::sourceparts')

def split_options(raw):
    table = str.maketrans({
        "[": None,
        "]": None
    })
    options = raw.translate(table).split(' ')

    return options

def auto_destination(uri):
    basename = uri
    basename = re.sub('\[[^\]]+\]', '', basename)
    basename = re.sub('\w+://', '', basename)
    basename = '_'.join(re.sub('[^a-zA-Z0-9]', ' ', basename).split())
    return '%s.sources' % basename


def destination(matches):
    for search_str in destinations.keys():
        search_pattern = re.compile(f'{search_str}(/|\s|$)')
        if re.search(search_pattern, matches['uri']) or re.search(search_pattern, matches["suite"]):
            return destinations[search_str]
    # fallback if nothing matches
    return auto_destination(matches['uri'])

def prepare_sources(lines):
    sources = {}
    pattern = re.compile('^(?: *(?P<type>deb|deb-src)) +(?P<options>\[.+\] ?)*(?P<uri>\w+:\/\/\S+) +(?P<suite>\S+)(?: +(?P<components>.*))?$')

    for line in lines:
        matches = re.match(pattern, line)

        if matches is not None:
            dest = destination(matches)
            options = {}

            if matches.group('options'):
                for option in split_options(matches['options']):
                    if "=" in option:
                        key, value = option.split("=")
                        options[key] = value

            if dest in sources:
                sources[dest]["Types"].add(matches["type"])
                sources[dest]["URIs"] = matches["uri"]
                sources[dest]["Suites"].add(matches["suite"])
                sources[dest]["Components"].update(matches["components"].split(' '))
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

                sources[dest] = source
    return sources

def save_sources(sources, output_dir):
    # print(output_dir)
    # print(sources)
    for dest, source in sources.items():
        source_path = output_dir + dest

        with open(source_path, 'w') as file:
            for key, value in source.items():
                if isinstance(value, str):
                    file.write("{}: {}\n".format(key, value))
                else:
                    file.write("{}: {}\n".format(key, ' '.join(value)))

def main():
    if select.select([sys.stdin, ], [], [], 0.0)[0]:
        sources = prepare_sources(sys.stdin)
    # elif len(sys.argv) > 1:
    #     sources = prepare_sources([sys.argv[1]])
    else:
        print("You must provide source lines to stdin", file=sys.stderr)
        sys.exit(1)

    output_dir = apt_pkg.config.find_dir('Dir::Etc::sourceparts')
    save_sources(sources, output_dir)

if __name__ == "__main__":
    main()

sys.exit(0)