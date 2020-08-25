#!/usr/bin/env python3

import getopt
import sys
import urllib.request
import json

# don't need right now
import re


# ==========================
# End of configuration steps
# ==========================

def parse_args():

    global source_host, destination_host, page_limit, connect_type
    # default values
    source_host      = "10.10.10.10:5000"
    destination_host = "10.10.10.10:5001"
    page_limit       = 5000
    connect_type     = "http://"


    try:
        opts, args = getopt.getopt(sys.argv[1:], 'h:', [ 'help', 'source=', 'src=', 'destination=', 'dest=', 'page_limit=', 'connect_type='])
    except getopt.GetoptError as error:
        print(str(error))
        print("Run '%s --help' for further information" % sys.argv[0])
        sys.exit(2)

    for opt, arg in opts:

        if opt == "-h" or opt == "--help":
            # TO DO - usage help
            #usage()
            print("You need help")
            sys.exit(2)

        if opt == "--page_limit":
            if not isinstance(arg, int):
                print('ERROR: Page limit', arg, 'is not integer')
                sys.exit(1)
            page_limit = arg

        if opt == "--connect_type":
            if arg != 'http' or arg != 'https':
                print('ERROR: Unknown connect type-', arg, '\nConnect type must be "http" or "https"')
                sys.exit(1)
            connect_type = arg

        if opt == "--src" or opt == "--source":
            # TO DO - add validation?
            arg     = arg.split(':')
            arg_len = arg.__len__()
            # checking if we have port field
            if arg_len == 2:
                # checking if port in appropriate range
                port = int(arg[1])
                if port not in range(1025, 65535):
                    print("Unappropriate port:", port)
                    sys.exit(1)
            elif arg_len > 2:
                print("Unappropriate host format:", ':'.join(arg))
                sys.exit(1)
            elif arg_len == 1:
                # set default docker registry port
                arg.append("5000")
            else:
                print("Unknown error with hostname", ':'.join(arg))
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
                if port not in range(1025, 65535) or port != 443:
                    print("Unappropriate port:", port)
                    sys.exit(1)
            elif arg_len > 2:
                print("Unappropriate host format:", ':'.join(arg))
                sys.exit(1)
            elif arg_len == 1:
                # set default docker registry port
                arg.append("5000")
            else:
                print("Unknown error with hostname", ':'.join(arg))
                sys.exit(1)
            # set default source host
            destination_host= ':'.join(arg)


def get_projects_tags_dict():
    global src_projects_tags_dict
    src_projects_tags_dict = {}

    url_path = connect_type + source_host + '/v2/_catalog?n=' + str(page_limit)


    with urllib.request.urlopen(url_path) as response:
        data = json.loads(response.read().decode())

    for proj in data['repositories']:
        # src_projects_tags_dict[x] =

        # http://10.10.10.10:5000/v2/${proj}/tags/list
        url_path = connect_type + source_host + '/v2/' + proj + '/tags/list'
        with urllib.request.urlopen(url_path) as response:
            tags = json.loads(response.read().decode())
        #print(proj)
        #print(tags['tags'])
        if not tags['tags']:
            continue
        tags['tags'].remove('latest')
        #src_projects_tags_dict[proj] = tags['tags']
        src_projects_tags_dict[proj] = { 'tags': None, 'latest': None }
        src_projects_tags_dict[proj]['tags'] = tags['tags']

        # sorting tags to find latest
        latest_pipeline_id = 0
        for tag in src_projects_tags_dict[proj]['tags']:
            #print(proj, tag)
            pipeline_id = tag.split('.')
            # drop testing one integer tags
            if pipeline_id.__len__() != 4:
                src_projects_tags_dict[proj]['tags'].remove(tag)
                continue
            pipeline_id = int(pipeline_id[3])

        if pipeline_id > latest_pipeline_id:
                latest_tag = tag
        src_projects_tags_dict[proj]['latest'] = latest_tag


    print(src_projects_tags_dict)







def main():
    parse_args()

    #print(source_host, destination_host)

    get_projects_tags_dict()


    # main configuration steps



if __name__ == "__main__":
    main()
