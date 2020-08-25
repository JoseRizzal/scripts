#!/usr/bin/env python3

import getopt
import sys
import os
import urllib.request
import json
# this one you'll need to install via pip3
import docker
# for logging
import datetime

# don't need right now
import re


# ==========================
# End of configuration steps
# ==========================

def usage():
    argv0 = sys.argv[0].split('/').pop()
    print("""
Usage:
------

     {argv0} [options]

Options:
    -h, --help:
        Display usage information

    -s, --sync:
        Sync mode 'sync' (upload new images, set new 'latest' tag if needed).
        Default option

    -f, --force:
        Sync mode 'force' (upload all images anew, set new 'latest' tags).

    --src=<host:port>, --source=<host:port>:
        Source host with optional port
        Default is 10.2.16.5:5000 right now

    --dest=<host:port>, --destination=<host:port>:
        Destination host with optional port
        Default is 10.2.16.5:5001 right now

    --log_mod=[parallel, file, console]:
        Set logging mode:
            parallel - log into console and into file (from --log_dir)
            file     - log into file (from --log_dir)
            console  - (default) log into console

    --lod_dir=<path/to/log_dir>
        Set dir for logging
        Default: <path/to/script>/log

    --page_limit:
        Set limit for projects in transfer
        Default is 5000 (probably you don't need more)
""".format(**locals())
          )


def parse_args():

    global source_host, destination_host, page_limit, sync_mode, log_mod, log_dir, t_zone
    # default values
    source_host      = "10.10.10.10:5000"
    destination_host = "10.10.10.10:5001"
    page_limit       = 5000
    sync_mode        = 'sync'
    #log_mod          = 'console'
    log_mod          = 'parallel'
    # set timezone globally
    t_zone           = datetime.datetime.now(datetime.timezone.utc).astimezone().tzname()

    # set logging dir (by default - where is script)
    log_dir          = sys.argv[0].split('/')
    log_dir.pop()
    log_dir.append('log')
    log_dir          = '/'.join(log_dir)


    try:
        opts, args = getopt.getopt(sys.argv[1:], 'hsf:', [ 'help', 'sync', 'force', 'log_mod=', 'log_dir=', 'source=', 'src=', 'destination=', 'dest=', 'page_limit='])
    except getopt.GetoptError as error:
        print(str(error))
        print("Run '%s --help' for further information" % sys.argv[0])
        sys.exit(2)



    # at first - set logging

    for opt, arg in opts:

        if opt == "-h" or opt == "--help":
            # TO DO - usage help
            usage()
            sys.exit(2)

        # logging opts
        # default - console
        if opt == "--log_mod":
            if arg == 'parallel':
                log_mod = 'parallel'
            elif arg == 'console':
                log_mod = 'console'
            elif arg == 'file':
                log_mod = 'file'
            else:
                color_console_msg('ERROR: Unknown log_mod:', arg)
                sys.exit(1)

        if opt == "--log_dir":
            log_dir = arg

    # push log mod
    set_logging()


    # set other options
    for opt, arg in opts:

        if opt == '-s' or opt == '--sync':
            sync_mode        = 'sync'
        if opt == '-f' or opt == '--force':
            sync_mode        = 'force'

        if opt == "--page_limit":
            if not isinstance(int(arg), int):
                msg_mgr('ERROR: Page limit', arg, 'is not integer')
                sys.exit(1)
            page_limit = arg

        if opt == "--src" or opt == "--source":
            # TO DO - add validation?
            arg     = arg.split(':')
            arg_len = arg.__len__()
            # checking if we have port field
            if arg_len == 2:
                # checking if port in appropriate range
                port = int(arg[1])
                if port not in range(1, 65535):
                    msg_mgr("ERROR: Unappropriate port:", port)
                    sys.exit(1)
            elif arg_len > 2:
                msg_mgr("ERROR: Unappropriate host format:", ':'.join(arg))
                sys.exit(1)
            elif arg_len == 1:
                # set default docker registry port
                arg.append("5000")
            else:
                msg_mgr("ERROR: Unknown error with hostname", ':'.join(arg))
                sys.exit(1)
            # set default source host
            source_host = ':'.join(arg)

        if opt == "--dest" or opt == "--destination":
            # TO DO - add validation?
            arg     = arg.split(':')
            arg_len = arg.__len__()
            # checking if we have port field
            if arg_len == 2:
                # checking if port in appropriate range
                port = int(arg[1])
                # can we use 443?
                # maybe we can
                if port not in range(1, 65535):
                    msg_mgr("ERROR: Unappropriate port:", port)
                    sys.exit(1)
            elif arg_len > 2:
                msg_mgr("ERROR: Unappropriate host format:", ':'.join(arg))
                sys.exit(1)
            elif arg_len == 1:
                # set default docker registry port
                arg.append("5000")
            else:
                msg_mgr("ERROR: Unknown error with hostname", ':'.join(arg))
                sys.exit(1)
            # set default source host
            destination_host = ':'.join(arg)


# Color console messages

def color_console_msg(*args, **kwargs):

    # default color mode
    color_mode = 'standard'

    for arg in args:
        tokens = arg.split()
        for token in tokens:
            if token == 'ERROR:':
                color_mode = 'error'
                break
            if token == 'WARNING:':
                color_mode = 'warning'
                break
            if token == 'NOTE:':
                color_mode = 'note'
                break
        if color_mode != 'standard':
            break

    # check color modes
    if color_mode == 'error':
        # red message
        print("\033[31m", *args, "\033[0m", file=sys.stderr, **kwargs)
    if color_mode == 'warning':
        # yellow mesage
        print("\033[33m", *args, "\033[0m", file=sys.stdout, **kwargs)
    if color_mode == 'note':
        # magenta message
        print("\033[35m", *args, "\033[0m", file=sys.stdout, **kwargs)
    if color_mode == 'standard':
        # magenta message
        print(*args, file=sys.stdout, **kwargs)


# universal message manager - logging, console etc
def msg_mgr(*args, **kwargs):

    # print console
    if log_mod in ('parallel', 'console'):
        color_console_msg(*args, **kwargs)

    if log_mod in ('parallel', 'file'):
        print(return_time(), '        ', *args, **kwargs, file=logfile)



def return_time():

    # return formatted time with timezone
    now = datetime.datetime.now()
    # eg - [2020-03-27 13:16:40 UTC]
    now = '[' + str(now).split('.')[0] + ' ' + t_zone + ']'
    return now


def set_logging():

    global logfile

    # open logfile if there is option

    if log_mod in ('parallel', 'file'):

        global logfile

        # set filename based on timestamp + timezone
        logfile_name = return_time()
        logfile_name = logfile_name.replace('[', '').replace(']', '').split()
        logfile_name = '_'.join(logfile_name) + '_docker_registry_transfer_log'

        # checking if we have directory for log
        # TO DO - set exception for permissions etc
        if not os.path.isdir(log_dir):
            os.makedirs(log_dir)

        logfile_name = log_dir + '/' + logfile_name

        try:
            logfile = open(logfile_name, 'w')
        except:
            color_error('Cannot open file', logfile_name)
            exit(1)

        print(return_time(), '        ', 'STARTED LOGGING', file=logfile)


def checking_src_and_dest():

    global source_host, destination_host

    # checking source host

    # checking http
    url_path_http = 'http://' + source_host + '/v2/_catalog?n=' + str(page_limit)
    # checking https
    url_path_https = 'https://' + source_host + '/v2/_catalog?n=' + str(page_limit)

    try:
        with urllib.request.urlopen(url_path_http) as response:
            data = json.loads(response.read().decode())
        # reset source host to view as connect_type + host_name
        source_host = 'http://' + source_host
    except:
        try:
            with urllib.request.urlopen(url_path_https) as response:
                data = json.loads(response.read().decode())
            # reset source host to view as connect_type + host_name
            source_host = 'https://' + source_host
        except:
            msg_mgr("ERROR: Can't get any data for source host:", '\n\t' + url_path_http, '\n\t' + url_path_https )
            sys.exit(1)

    if not data['repositories']:
        msg_mgr('ERROR: Empty source repo, nothing to transfer')
        sys.exit(1)

    # checking destination host

    # checking http
    url_path_http = 'http://' + destination_host + '/v2/_catalog?n=' + str(page_limit)
    # checking https
    url_path_https = 'https://' + destination_host + '/v2/_catalog?n=' + str(page_limit)

    try:
        with urllib.request.urlopen(url_path_http) as response:
            data = json.loads(response.read().decode())
        # reset source host to view as connect_type + host_name
        destination_host = 'http://' + destination_host
    except:
        try:
            with urllib.request.urlopen(url_path_https) as response:
                data = json.loads(response.read().decode())
            # reset source host to view as connect_type + host_name
            destination_host = 'https://' + destination_host
        except:
            msg_mgr("ERROR: Can't get any data for destination host:", '\n\t' + url_path_http, '\n\t' + url_path_https )
            sys.exit(1)

    if not data['repositories']:
        msg_mgr('ERROR: Empty destination repo, set sync_mode to "force"')
        sync_mode = 'force'

    #print(source_host, destination_host)
    #sys.exit(1)



def get_projects_tags_dict(connected_host):

    global src_projects_tags_dict
    src_projects_tags_dict = {}

    url_path = connected_host + '/v2/_catalog?n=' + str(page_limit)


    with urllib.request.urlopen(url_path) as response:
        data = json.loads(response.read().decode())

    for proj in data['repositories']:
        # src_projects_tags_dict[x] =

        # http://10.10.10.10:5000/v2/${proj}/tags/list
        url_path = connected_host + '/v2/' + proj + '/tags/list'
        with urllib.request.urlopen(url_path) as response:
            tags = json.loads(response.read().decode())
        # skip empty tags
        if not tags['tags']:
            continue
        # remove tag latest, will bind it below to
        # remove if we have tag 'latest'
        if 'latest' in tags['tags']:
            tags['tags'].remove('latest')
        src_projects_tags_dict[proj] = { 'tags': None, 'latest': None }
        src_projects_tags_dict[proj]['tags'] = tags['tags']
        # sorting tags to find latest
        latest_pipeline_id = 0


        # populate with tags for remove
        tags_for_remove = []

        for tag in src_projects_tags_dict[proj]['tags']:

            pipeline_id = tag.split('.')
            # drop testing one integer tags
            if pipeline_id.__len__() != 4:
                tags_for_remove.append(tag)
                continue
            pipeline_id = int(pipeline_id[3])


            if pipeline_id > latest_pipeline_id:
                latest_pipeline_id = pipeline_id
                latest_tag = tag
        src_projects_tags_dict[proj]['latest'] = latest_tag

        if tags_for_remove:
            for tag in tags_for_remove:
                src_projects_tags_dict[proj]['tags'].remove(tag)


def sync_repos():

    # default option - 'sync'
    if sync_mode == 'sync':

        # save main src dictionary copy
        copy_src_projects_tags_dict = { key:value for key, value in src_projects_tags_dict.items() }
        get_projects_tags_dict(destination_host)
        # save dest dictionary copy, comprehension type for subsequent clear command
        dest_projects_tags_dict = { key:value for key, value in src_projects_tags_dict.items() }
        # clear main dict
        src_projects_tags_dict.clear()

        # compare two dict
        src_keys  = copy_src_projects_tags_dict.keys()
        dest_keys = dest_projects_tags_dict.keys()


        for proj in src_keys:
            # check project in dest dict
            if proj in dest_keys:
                filtered_tags = []
                for tag in copy_src_projects_tags_dict[proj]['tags']:
                    if not tag in dest_projects_tags_dict[proj]['tags']:
                        filtered_tags.append(tag)
                if filtered_tags:
                    src_projects_tags_dict[proj] = { 'tags': filtered_tags }
                    # compare latest tags
                    if copy_src_projects_tags_dict[proj]['latest'] != dest_projects_tags_dict[proj]['latest']:

                        #print(proj)
                        #print('Src :', copy_src_projects_tags_dict[proj]['latest'])
                        #print('Dest:', dest_projects_tags_dict[proj]['latest'])


                        # compare
                        src_ci_pipeline_id  = int(copy_src_projects_tags_dict[proj]['latest'].split('.')[3])
                        dest_ci_pipeline_id = int(dest_projects_tags_dict[proj]['latest'].split('.')[3])

                        if src_ci_pipeline_id == dest_ci_pipeline_id:
                            src_projects_tags_dict[proj]['latest'] = 'without_change'
                        elif src_ci_pipeline_id > dest_ci_pipeline_id:
                            src_projects_tags_dict[proj]['latest'] = copy_src_projects_tags_dict[proj]['latest']
                        elif src_ci_pipeline_id < dest_ci_pipeline_id:
                            src_projects_tags_dict[proj]['latest'] = dest_projects_tags_dict[proj]['latest']
                        else:
                            msg_mgr('ERROR: Unknown latest tags comparision:', copy_src_projects_tags_dict[proj]['latest'], dest_projects_tags_dict[proj]['latest'])
                            sys.exit(1)
            else:
                # is it legitime in python?
                src_projects_tags_dict[proj] = copy_src_projects_tags_dict[proj]


        if not src_projects_tags_dict:
            msg_mgr('Sync not needed: repos unchanged')
            sys.exit(0)
        msg_mgr('Syncing changed:')
        #print(src_projects_tags_dict, '\nThis is the destination host')


def push_to_dest():

    docker_client = docker.from_env()
    projects = src_projects_tags_dict.keys()
    counter = 1

    # stripping source and destination from 'http://'|'https://'
    bare_source_host      = source_host.split('/')[2]
    bare_destination_host = destination_host.split('/')[2]

    # we get filtered dict for writing
    for proj in projects:
        # need to redirect in log, if there is a option
        msg_mgr(str(counter) + '. Transfer tags for', proj)
        counter+=1
        c = 1

        for tag in src_projects_tags_dict[proj]['tags']:
            # info to console
            msg_mgr('\t', str(c) + '.', tag)
            c+=1
            # e.g. - 10.2.16.5:5000/mass-develop:1.2.3.4
            image_src  = bare_source_host + '/' + proj + ':' + tag
            image_dest = bare_destination_host + '/' + proj + ':' + tag

            # working with docker connector
            docker_client.images.pull(image_src)
            msg_mgr('\t\t', 'pull - success')

            # tagging
            current_img = docker_client.images.get(image_src)
            current_img.tag(image_dest)
            msg_mgr('\t\t', 'tag - success')

            # push to other repo
            docker_client.images.push(image_dest)
            msg_mgr('\t\t', 'push - success')

            # checking latest tag
            # 'without_change' for sync mode
            if tag == src_projects_tags_dict[proj]['latest'] and src_projects_tags_dict[proj]['latest'] != 'without_change':
                image_latest = bare_destination_host + '/' + proj + ':' + 'latest'
                # tagging
                current_img = docker_client.images.get(image_src)
                current_img.tag(image_latest)
                msg_mgr('\t\t', 'latest tag - success')
                #push to other repo
                docker_client.images.push(image_latest)
                msg_mgr('\t\t', 'latest push - success')
                # remove tag
                docker_client.images.remove(image_latest)
                msg_mgr('\t\t', 'latest local remove - success')

            # clean local repo
            docker_client.images.remove(image_src)
            docker_client.images.remove(image_dest)
            msg_mgr('\t\t', 'local remove - success')

        ###
        #sys.exit(1)



def main():

    parse_args()
    checking_src_and_dest()
    get_projects_tags_dict(source_host)
    sync_repos()

    push_to_dest()


    # main configuration steps



if __name__ == "__main__":
    main()
