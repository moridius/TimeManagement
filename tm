#!/usr/bin/env python3

import argparse
import sys
import os
import os.path
import datetime


gDataDir = os.path.expanduser('~') + "/.tm/"
gTasksFile = gDataDir + "tasks.txt"
gLogFile   = gDataDir + "log.txt"


class TimeLogEntry():
    def __init__( self ):
        self.dt = None
        self.task = None

class TimeLog():
    def __init__( self, logFile ):
        self.logFile = logFile
        self.logList = []
        self.changed = False

    def start( self ):
        try:
            with open( self.logFile, 'r' ) as f:
                for line in f:
                    obj = TimeLogEntry()
                    splitted = line.strip().split()
                    obj.dt = datetime.datetime.fromtimestamp( int(splitted[0]) )
                    obj.task = splitted[1]
                    self.logList.append( obj )
        except KeyboardInterrupt:
            pass

    def end( self ):
        if self.changed:
            try:
                with open( self.logFile, 'w' ) as f:
                    for entry in self.logList:
                        f.write( str( int( entry.dt.timestamp() ) ) + ' ' + entry.task + '\n' )
            except KeyboardInterrupt:
                pass

    def __enter__( self ):
        self.start()
        return self

    def __exit__( self, excType, excValue, traceback ):
        self.end()

    def AddLogEntry( self, task ):
        now = datetime.datetime.now()
        entry = TimeLogEntry()
        entry.dt = now
        entry.task = task.strip()
        self.logList.append( entry )
        self.changed = True
        return now

    def GetLastEntry( self ):
        return self.logList[-1]


class AmbiguousTerm( Exception ):
    pass


class TaskList():
    def __init__( self, taskFile ):
        self.taskFile = taskFile
        self.taskList = []
        self.changed  = False

    def start( self ):
        try:
            with open( self.taskFile, 'r' ) as f:
                self.taskList = f.readlines()
        except KeyboardInterrupt:
            pass

    def end( self ):
        if self.changed:
            try:
                with open( self.taskFile, 'w' ) as f:
                    f.writelines( self.taskList )
            except KeyboardInterrupt:
                pass

    def __enter__( self ):
        self.start()
        return self

    def __exit__( self, excType, excValue, traceback ):
        self.end()

    def FindTask( self, term ):
        full_task = ''
        for task in self.taskList:
            if task.lower().startswith( term.lower() ):
                if full_task == '':
                    full_task = task.strip()
                else:
                    raise AmbiguousTerm()
        return full_task


########################################

def Init( dataDir ):
    if not os.path.isdir( dataDir ):
        os.mkdir( dataDir )
        print( "Made data directory: " + dataDir )

def Exit( msg='', code=0 ):
    if msg != '':
        if code == 0:
            print( msg )
        else:
            print( msg, file=sys.stderr )
    sys.exit( code )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument( "cmd", choices=["start", "stop", "status"] )
    parser.add_argument( "task", nargs='?' )
    args = parser.parse_args()

    Init( gDataDir )

    with TaskList( gTasksFile ) as task_list, TimeLog( gLogFile ) as time_log:
        if args.cmd == "start":
            try:
                task = task_list.FindTask( args.task )
                if task == '':
                    Exit( 'Task not found. Add new tasks with command "new".', 1 )
            except AmbiguousTerm:
                Exit( 'Ambiguous.', 2 )

            try:
                last_entry = time_log.GetLastEntry()
                if last_entry.task == task:
                    Exit( 'Already running.', 3 )
            except IndexError:
                pass

            time_log.AddLogEntry( task )
            Exit( 'Started: "' + task + '" (' + datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S') + ')' )

        elif args.cmd == "stop":
            last_task = args.cmd
            try:
                last_entry = time_log.GetLastEntry()
                last_task = last_entry.task
            except IndexError:
                pass
            if last_task == args.cmd:
                Exit( 'Already stopped.', 4 )

            time_log.AddLogEntry( args.cmd )
            Exit( 'Stopped (' + datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S') + ')' )

        elif args.cmd == "status":
            last_task = "stop"
            try:
                last_entry = time_log.GetLastEntry()
                last_task = last_entry.task
            except IndexError:
                pass

            text = ""
            if last_task == "stop":
                text = "Stopped"
            else:
                text = 'Current project: "' + last_task + '"'
            Exit( text + " (since " + last_entry.dt.strftime('%Y-%m-%d %H:%M:%S') + ")" )
