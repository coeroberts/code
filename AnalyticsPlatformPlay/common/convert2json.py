import os
import json

project_dir = os.getcwd()

old_extensions = ["final", "user", "shared"]

segments = list()


def get_property(line):
    prop = dict()
    pair = line.split("=")
    if len(pair) == 2:
        prop["name"] = pair[0]
        prop["value"] = pair[1]
        return prop
    else:
        return None


def add_properties(file_name):
    f = open(file_name, "r")
    properties = list()
    for line in f:
        stripped_line = line.rstrip('\n')
        if not line.startswith("#"):
            prop = get_property(stripped_line)
            if prop is not None:
                properties.append(prop)
    return properties


def add_segment(extension):
    file_name = str.format("{}/job.properties.{}", project_dir, extension)
    if os.path.exists(file_name):
        segment = dict()
        segment["environment"] = "*"
        namespace = extension
        if namespace == "shared":
            namespace = "*"
        segment["namespace"] = namespace
        segment["properties"] = add_properties(file_name)
        segments.append(segment)

for ext in old_extensions:
    add_segment(ext)

output_file = open(project_dir + "/job.properties.json", "w")
json.dump(segments, output_file, indent=4)
output_file.close()
