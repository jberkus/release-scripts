#!/usr/bin/env python

import sys
import json
import csv

f = open(sys.argv[1], "r")
j = json.load(f)
issues = j["data"]["search"]["edges"]

labdict = {}
iout = []

for issue in issues:
  if "url" in issue["node"]:
    labdict = { "url" : issue["node"]["url"],
        "title" : issue["node"]["title"],
        "kind" : [],
        "sig" : [],
        "priority" : [],
        "area" : [],
        "status" : [],
        "other" : [] }

    if "labels" in issue["node"]:
          for label in issue["node"]["labels"]["edges"]:
              if "name" in label["node"]:
                  #ilabs.append(label["node"]["name"])
                  labd = label["node"]["name"].split("/")
                  if len(labd) == 2:
                      if labd[0] in [ "kind", "sig", "priority", "area", "status" ]:
                          labdict[labd[0]].append(labd[1])
                      else:
                          labdict["other"].append(label["node"]["name"])
                  else:
                     labdict["other"].append(label["node"]["name"])

    for key, value in labdict.items():
        if type(value) is list:
            labdict[key] = ",".join(value)

    iout.append([labdict["url"], labdict["title"], labdict["kind"], labdict["sig"], labdict["priority"],
        labdict["area"], labdict["status"], labdict["other"]])

with open('issues.csv', 'wb') as csv_file:
    writer = csv.writer(csv_file)
    for lrow in iout:
       writer.writerow(lrow)

f.close()
