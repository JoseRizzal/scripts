#!/usr/bin/env python3

import urllib.request
# for time sync
import datetime
# for command line args
import sys
# for tags and data parsing
from html.parser import HTMLParser
# regex
import re

import subprocess

import os.path




#url = 'https://filecrypt.co/Container/1E97EFD863.html'

class MyHTMLParser(HTMLParser):

    _link_pool = ''
    _root_list = []

    def handle_starttag(self, tag, attrs):
        #if tag == 'button' and attrs[0][0] == 'href':
        if tag == 'button' and attrs[0][0] == 'onclick':
            # if ('class', 'download')
            download_check = attrs[1][1]
            if download_check == 'download':
                link_raw = attrs[0][1]
                list_raw = link_raw.split('\'')

                if list_raw[0] == 'openLink(':
                    # append link
                    MyHTMLParser._root_list.append("http://filecrypt.co/Link/" + list_raw[1] + '.html')
                    #print("http://filecrypt.co/Link/" + list_raw[1])

        # parsing redirection pages
        if tag == 'iframe' and attrs[0][0] == 'allowfullscreen' and attrs[2][0] == 'src':
            MyHTMLParser._link_pool = attrs[2][1]
            #print(redirect_link)

        #if tag == 'a' and attrs[0][0] == 'id' and attrs[0][1] == 'dlbutton':
        #if tag == 'a':
        #    print(attrs)



    def handle_data(self, data):

        if re.search(r'dlbutton', data) and re.search(r'(\.rar)|(\.zip)', data):

            data = data.strip()

            raw_data_list = data.split('\n')



            for line in raw_data_list:
                # TO DO! - check 'dlbutton'
                href_regex = re.search(r'href.+', line)
                if href_regex:

                    # list with tokens from raw links
                    href_link_raw = href_regex.group(0).split()

                    # start to compute our download link from base link
                    download_link = ""
                    math_expression = ""

                    for item in href_link_raw:
                        # get rid from attr tag
                        if item == 'href' or item == '=':
                            continue
                        else:
                            # getting plain string
                            if re.search(r'\"', item):
                                download_link += item.strip(';').strip('\"')

                            # compute math
                            # start expression
                            elif re.search(r'\(', item):
                                math_expression += item
                                #print("add to math expression")

                            # close expression
                            elif re.search(r'\)', item):
                                math_expression += item
                                #print(math_expression)
                                download_link += str(eval(math_expression))
                                math_expression = ""
                            # adding to math expression
                            elif math_expression:
                                math_expression += item

                    # set universal link var
                    MyHTMLParser._link_pool = download_link

                    # stop loop from parsing all that not 'dlbutton'
                    break


    def get_link(self):
        return MyHTMLParser._link_pool

    def get_arch_name(self):
        return MyHTMLParser._link_pool.split('/')[-1]

    def get_root_list(self):
        return MyHTMLParser._root_list



# TO DO - get rid of subprocesses!
def curl_cmd(cmd):
    subprocess.run(['/bin/bash', '-c', cmd])


#--------------------------------------------#


def get_args():

    global params, parser

    # set current data
    #now = datetime.datetime.now()
    params = {}
    #root_links = {}
    #params = {'root_url': 'kl'}
    # get args
    params['root_url'] = sys.argv[1]
    # set takes for link connection
    params['takes'] = 3
    #params['root_url'] = 'https://filecrypt.co/Container/1E97EFD863.html'
    #print(sys.argv[1])
    parser = MyHTMLParser()


def url_connect(req, mode='only_html'):

    takes = params['takes']

    # for zippy list
    if mode == 'html_and_headers':

        for i in range(takes):
            try:
                with urllib.request.urlopen(req) as response:
                        html_page = response.read().decode()
                        headers = response.getheaders()        
                break

            except:
                print('WARNING: HTTPError, reconnect...')
                if takes - i == 1:
                    print('ERROR: HTTPError, abort reconnection')
                    sys.exit(1)

        return html_page, headers

    if mode == 'only_html':

        for i in range(takes):
            try:
                with urllib.request.urlopen(req) as response:
                        html_page = response.read().decode() 
                break

            except:
                print('WARNING: HTTPError, reconnect...')
                if takes - i == 1:
                    print('ERROR: HTTPError, abort reconnection')
                    sys.exit(1)



        return html_page


    if mode == 'location':

        for i in range(takes):
            try:
                with urllib.request.urlopen(req) as response:
                    location = response.geturl() 
                break

            #except urllib.error.HTTPError as exception:
            #    search_error_code_status = re.search(r'500', exception)
            #    if search_error_code_status:
            #        print('WARNING: Internal Server Error, reconnect...')

            #        if takes - i == 1:
            #            print('ERROR: Internal Server Error, abort reconnection')
            #            sys.exit(1)
            #    else:
            #        print(exception)
            #        sys.exit(1)

            except:
                print('WARNING: HTTPError, reconnect...')
                if takes - i == 1:
                    print('ERROR: HTTPError, abort reconnection')
                    sys.exit(1)


        return location


def get_root_links():

    url = params['root_url']
    #cookies = "Cookie: "
    cookies = ''


    with urllib.request.urlopen(url) as response:
        html_page = response.read().decode()
        headers = response.getheaders()


    for h in headers:
        if h[0] == 'Set-Cookie':
            #print(h[1].split(';')[0])
            #cookies.append(h[1].split(';')[0])
            cookies += h[1].split(';')[0] + "; "

    #cookies = {"Cookie": cookies}

    #print(cookies)

    parser.feed(html_page)

    #print(root_list)
    params['root_list'] = parser.get_root_list()
    params['cookies'] = cookies


def get_zippy_links():


    zippy_list = []
    root_list = params['root_list']
    #cookies = "Cookie: "
    cookies = params['cookies']


    print('-----------')
    print('Getting zippyshare locations list, please wait ...')
    print('-----------')

    # declare counter
    i = 1

    for link in root_list:

        print('Link', i, 'from', link)

        req = urllib.request.Request(link)
        req.add_header("Cookie", cookies)

        # TODO! Check statuses


        html_page = url_connect(req, mode='only_html')


        #with urllib.request.urlopen(req) as response:
        #    html_page = response.read().decode()



        # parsing page for redirection link
        parser.feed(html_page)

        #print('redirect_link is', parser.get_link())

        print('Redirect', i, 'to', parser.get_link())

        req = urllib.request.Request(parser.get_link())
        req.add_header("Cookie", cookies)



        location = url_connect(req, mode='location')

        #with urllib.request.urlopen(req) as response:
            #html_page = response.read().decode()
            #redir_headers = response.getheaders()
        #    location = response.geturl()

        zippy_list.append(location)
        print('Location', i, 'is', location)
        print('-----------')


        i+=1

    params['zippy_list'] = zippy_list




def zippy_downloads():

    zippy_list = params['zippy_list']
    # get cookies
    cookies = ""

    #print(zippy_list)

    i = 1

    for link in zippy_list:

        # e.g. present as
        #    https://www39.zippyshare.com
        base_link = '/'.join(link.split('/')[0:3])


        html_page, headers = url_connect(link, mode='html_and_headers')

        #with urllib.request.urlopen(link) as response:
        #    html_page = response.read().decode()
        #    headers = response.getheaders()


        for h in headers:
            if h[0] == 'Set-Cookie':
                #print(h[1].split(';')[0])
                #cookies.append(h[1].split(';')[0])
                cookies += h[1].split(';')[0] + "; "


        # get zippy download buttons
        parser.feed(html_page)

        download_link = base_link + parser.get_link()
        arch_name = parser.get_arch_name()
            #print(cookies)

        # Service messages
        print('------')
        print(i, '-- Downloading file', arch_name, 'please wait ...')
        print('------')
        i+=1


        # check if we have file in directory
        file_exist = './' + arch_name
        if os.path.isfile(file_exist): 
            print("Found", arch_name, 'in current directory, skip downloading')
            continue

        curl_str = 'curl -LO -H "Cookie: ' + cookies + '" ' + download_link 

        # TO DO! - multidownload with master proc (or something like this)
        curl_cmd(curl_str)



#--------------------------------------------#




def main():

    get_args()
    get_root_links()

    #print(params['root_list'])

    get_zippy_links()
    zippy_downloads()

    #print('Get parameter root_url -', params['root_url'])


    # main configuration steps



if __name__ == "__main__":
    main()
