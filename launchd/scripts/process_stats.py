#!/usr/bin/env python2
"""This script logs current process stats to a sqlite database"""
import argparse
import sqlite3
import subprocess
import time
from datetime import datetime
from os import getenv, path

TZ_OFFSET = time.strftime('%z')

def log_debug(msg):
	"""Print a debug message"""
	print("{0} {1} (ProcessStats) DEBUG {2}".format(datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3], TZ_OFFSET, msg))

log_debug("Starting ProcessStats...")

ARG_PARSER = argparse.ArgumentParser(description='Get process stats and write to sqlite3 database.')
ARG_PARSER.add_argument('-d', '--debug', action='store_true', help='Debug mode')
ARG_PARSER.add_argument('-v', '--verbose', action='store_true', help='Verbose mode')

ARGS = ARG_PARSER.parse_args()

USE_DB = not ARGS.debug

CURR_TIME = datetime.utcnow().isoformat(' ')
DB_FILE = getenv('HOME') + "/.logs/stats.db"
DB_EXISTS = path.isfile(DB_FILE)

if USE_DB:
	STATS_DB = sqlite3.connect(DB_FILE)
	DB_CURSOR = STATS_DB.cursor()

if USE_DB and DB_EXISTS is False:
	DB_CURSOR.execute("CREATE TABLE processes (timestamp text, uid integer, user text, pid integer, ppid integer, start_time text, cpu_pct real, mem_pct real, cpu_time text, command text)")

PS = subprocess.Popen(['ps', '-Ao', 'uid,user,pid,ppid,start,%cpu,%mem,time,command'], stdout=subprocess.PIPE).communicate()[0]
PROCESSES = PS.split('\n')
del PROCESSES[-1]
# this specifies the number of splits, so the splitted lines
# will have (NFIELDS+1) elements
FIELDS = PROCESSES[0].split()
NFIELDS = len(FIELDS) - 1
for row in PROCESSES[1:]:
	ROW_VALS = [CURR_TIME] + row.split(None, NFIELDS)
	# ROW_VALS[5] = datetime.strptime(ROW_VALS[5], "%c").strftime("%FT%TZ")
	if not USE_DB or ARGS.verbose:
		print(ROW_VALS)

	if USE_DB:
		# pylint: disable=C0301
		DB_CURSOR.execute("INSERT INTO PROCESSES values (?,?,?,?,?,?,?,?,?,?)", (ROW_VALS[0], ROW_VALS[1], ROW_VALS[2], ROW_VALS[3], ROW_VALS[4], ROW_VALS[5], ROW_VALS[6], ROW_VALS[7], ROW_VALS[8], ROW_VALS[9]))

if USE_DB:
	STATS_DB.commit()
	STATS_DB.close()

log_debug("Finished ProcessStats")
