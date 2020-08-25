#!/usr/bin/env python3

import json
# for URLDataHandler
import urllib.request
# for time sync
import datetime
# for command line args
import sys


def sort_constraits(t_stamp, type_s='all', p_id='none', pipe_id=None) -> int:
    # datetime + month 
    # need to move another 
    #now = datetime.datetime.now()
    #t_list = now.strftime("%Y-%m-%d").split('-')

    if type_s == 'day':
        if t_stamp[0] == t_list[0] and t_stamp[1] == t_list[1] and t_stamp[2] == t_list[2]:
            return 1
        else:
            return 0
    elif type_s == 'month':
        if t_stamp[0] == t_list[0] and t_stamp[1] == t_list[1]:
            return 1
        else:
            return 0
    elif type_s == 'year':
        if t_stamp[0] == t_list[0]:
            return 1
        else:
            return 0
    elif type_s == 'all':
        return 1

    # check for centain pipeline
    # CRUTCH DETECTED!!!
    elif pipe_id:

        #type_s = [ d_slice_year, d_slice_month, d_slice_day, d_srv_info]
        # init human readable vars:
        d_slice_year  = type_s[0]
        d_slice_month = type_s[1]
        d_slice_day   = type_s[2]

        url_path = gitlab_add + '/api/v4/projects/' + str(p_id) + '/pipelines/' + str(pipe_id) + '/' + ctrl_param + str(1)


        with urllib.request.urlopen(url_path) as response:
            data = json.loads(response.read().decode())
        # init data
        # get build time updates
        build_time_crd  = data['created_at']
        build_time_crd  = build_time_crd.replace('T','-').replace(':','-').split('.')[0]
        # get build time updates
        build_time_upd  = data['updated_at']
        build_time_upd  = build_time_upd.replace('T','-').replace(':','-').split('.')[0]
        
        # check if given time has pipeline

        # stat only on month data
        t_stamp_crd = build_time_crd.split('-')
        t_stamp_upd = build_time_upd.split('-')


        # check only year
        if d_slice_month == 'without_month' and d_slice_day == 'without_day':
            if int(t_stamp_crd[0]) == d_slice_year:
                return 1
            elif int(t_stamp_upd[0]) == d_slice_year:
                return 1
            #else:
            #    return 0
        # check only month
        elif d_slice_month != 'without_month' and d_slice_day == 'without_day':
            if int(t_stamp_crd[0]) == d_slice_year and int(t_stamp_crd[1]) == d_slice_month:
                return 1
            if int(t_stamp_upd[0]) == d_slice_year and int(t_stamp_upd[1]) == d_slice_month:
                return 1
            #else:
            #    return 0

        # check day of the month
        elif d_slice_month != 'without_month' and d_slice_day != 'without_day':
            if int(t_stamp_crd[0]) == d_slice_year and int(t_stamp_crd[1]) == d_slice_month and int(t_stamp_crd[2]) == d_slice_day:
                return 1
            elif int(t_stamp_upd[0]) == d_slice_year and int(t_stamp_upd[1]) == d_slice_month and int(t_stamp_upd[2]) == d_slice_day:
                return 1
                #else:
                #    return 0
        return 0


    # datailed query    
    elif type_s[3] == 'none':
        #type_s = [ d_slice_year, d_slice_month, d_slice_day, d_srv_info]
        # init human readable vars:
        d_slice_year  = type_s[0]
        d_slice_month = type_s[1]
        d_slice_day   = type_s[2]

        c = 1
        while c < pages_limit:    
            url_path = gitlab_add + '/api/v4/projects/' + str(p_id) + '/pipelines' + ctrl_param + str(c)
            c+=1

            with urllib.request.urlopen(url_path) as response:
                data = json.loads(response.read().decode())
            # don't iterate empty data
            if not data:
                break
            for item in data:
                # init data
                # get build time updates
                build_time_crd  = item['created_at']
                build_time_crd  = build_time_crd.replace('T','-').replace(':','-').split('.')[0]
                # get build time updates
                build_time_upd  = item['updated_at']
                build_time_upd  = build_time_upd.replace('T','-').replace(':','-').split('.')[0]
                
                # check if given time has pipeline

                # stat only on month data
                t_stamp_crd = build_time_crd.split('-')
                t_stamp_upd = build_time_upd.split('-')


                # check only year
                if d_slice_month == 'without_month' and d_slice_day == 'without_day':
                    if int(t_stamp_crd[0]) == d_slice_year:
                        return 1
                    elif int(t_stamp_upd[0]) == d_slice_year:
                        return 1
                    #else:
                    #    return 0
                # check only month
                elif d_slice_month != 'without_month' and d_slice_day == 'without_day':
                    if int(t_stamp_crd[0]) == d_slice_year and int(t_stamp_crd[1]) == d_slice_month:
                        return 1
                    if int(t_stamp_upd[0]) == d_slice_year and int(t_stamp_upd[1]) == d_slice_month:
                        return 1
                    #else:
                    #    return 0

                # check day of the month
                elif d_slice_month != 'without_month' and d_slice_day != 'without_day':
                    if int(t_stamp_crd[0]) == d_slice_year and int(t_stamp_crd[1]) == d_slice_month and int(t_stamp_crd[2]) == d_slice_day:
                        return 1
                    elif int(t_stamp_upd[0]) == d_slice_year and int(t_stamp_upd[1]) == d_slice_month and int(t_stamp_upd[2]) == d_slice_day:
                        return 1
                    #else:
                    #    return 0
        return 0

    # unknown data
    else:
        print('ERROR: Unknown type - ', type_s)
        sys.exit(1)





def fetch_data(url_path, counter):
    # trying to work with web data 
    # right now - simple way
    print('Procedure page:', counter)
    with urllib.request.urlopen(url_path) as response:
        data = json.loads(response.read().decode())
    # don't iterate empty data
    if not data:
        return 1
    for item in data:
        # init data
        p_id    = item['id']
        name    = item['name']
        c_time  = item['created_at']
        c_time  = c_time.replace('T','-').replace(':','-').split('.')[0]
        l_time  = item['last_activity_at']
        l_time  = l_time.replace('T','-').replace(':','-').split('.')[0]
        n_space = item['namespace']['full_path']
        # set data
        projects[p_id] = {'name': name, 'c_time': c_time, 'l_time': [l_time], 'n_space': n_space, 'p_id': p_id}
    return 0



def stat_data(p_id, type_s):

    # get all needed stat

    pipelines_counter = 0
    jobs_counter = 0
    gen_duration = 0
    gen_avr_duration = 0


    prj_info = []
    c = 1

    while c < pages_limit:    
        url_path = gitlab_add + '/api/v4/projects/' + str(p_id) + '/pipelines' + ctrl_param + str(c)
        c+=1

        with urllib.request.urlopen(url_path) as response:
            data = json.loads(response.read().decode())
        # don't iterate empty data
        if data == []:
            break
        for item in data:
            # init data
            # get pipeline id 
            pipe_id    = item['id']
            # get build time
            build_time  = item['updated_at']
            build_time  = build_time.replace('T','-').replace(':','-').split('.')[0]
            # branch var
            branch      = item['ref']

            # stat only on month data
            t_stamp = build_time.split('-')

            if sort_constraits(t_stamp, type_s, p_id, pipe_id):
                url_path = gitlab_add + '/api/v4/projects/' + str(p_id) + '/pipelines/' + str(pipe_id) + '/jobs' + ctrl_param + str(1)
                with urllib.request.urlopen(url_path) as response:
                    n_data = json.loads(response.read().decode())

                jobs_num = len(n_data)
                # get duration of jobs
                total_duration   = 0
                average_duration = 0

                if jobs_num != 0:
                    for job in n_data:
                        if job['duration'] == None:
                            continue
                        total_duration+=int(round(job['duration']))
                        # add margin ~ 25 sec to initiate job and pulling out build image
                        total_duration+=25
                    average_duration = round(total_duration/jobs_num)

                # convert seconds to munites
                total_duration   = round(total_duration/60)
                average_duration = round(average_duration/60)

                prj_info.append({ 'build_time': build_time, 'branch': branch, 'jobs_num': jobs_num, 'total_duration': total_duration, 'average_duration': average_duration })

    # set identations
    # check tabs
    if d_type == 'raw':
        init_tabs    = '\t'
        nested_tabs  = '\t\t'
    elif d_type == 'structure':
        init_tabs    = '\t\t'
        nested_tabs  = '\t\t\t'

    # print stat data

    print(init_tabs, '\'Builds\':           ')

    for x in prj_info:
        stat_rec = x['build_time'].split('-')
        stat_rec = '-'.join(map(str, stat_rec[2::-1]))
        print(nested_tabs, stat_rec + ':\t', '\tjobs:', x['jobs_num'], '\ttime:  ~' + str(x['total_duration']) + 'm', '\tbranch:', x['branch'])
        # count it all
        pipelines_counter+=1
        jobs_counter+=x['jobs_num']

        gen_duration+=x['total_duration']
        #gen_avr_duration = 0


    print(nested_tabs, '-----------')
    print(nested_tabs, '\'Total pipelines\':', pipelines_counter)
    print(nested_tabs, '\'Total jobs\':', jobs_counter)


    # generate correct time for duration:
    # check if our record has active jobs
    if jobs_counter != 0:
        gen_avr_duration = round(gen_duration/jobs_counter)
        if gen_duration > 60:
            gen_duration = '~ ' + str(round(gen_duration/60)) + ' h'
        else:
            gen_duration = '~ ' + str(gen_duration) + ' m'

        if gen_avr_duration > 60:
            gen_avr_duration = '~ ' + str(round(gen_avr_duration/60)) + ' h'
        else:
            gen_avr_duration = '~ ' + str(gen_avr_duration) + ' m'
    else:
        gen_duration = gen_avr_duration = '0 m'

    print(nested_tabs, '\'Total duration\':  ', gen_duration)
    print(nested_tabs, '\'Average duration\':  ', gen_avr_duration)

    # summary for append
    return { 'info': prj_info, 'pipelines_counter': pipelines_counter, 'jobs_counter': jobs_counter }


def print_raw_data(key, check_mode, c):
    print(str(c) + '.', projects[key]['name'])
    # custom pretty printer
    print('\t', '\'Name\':           \'' + projects[key]['name'] + '\'')
    print('\t', '\'Creation date\':  \'' + projects[key]['c_time'] + '\'')
    print('\t', '\'Latest build\':  ', projects[key]['l_time'])
    print('\t', '\'Namespace\':      \'' + projects[key]['n_space'] + '\'')
    # output statistic
    if d_stat == 'stat':
        # pass list
        result = stat_data(projects[key]['p_id'], check_mode)
        # view for result:
        # { 'info': prj_info, 'pipelines_counter': pipelines_counter, 'jobs_counter': jobs_counter }
        result['name'] = projects[key]['name']
        summary_list.append(result)
    # separate line
    print('-----------')


def data_sort(process='raw', sort_key='day'):

    # set check mode
    check_mode = sort_key[3]

    if process == 'raw':

        if check_mode in ('month', 'day', 'year', 'all'):
            # get all to february
            #print('Active projects:  ', t_list)
            print('All projects', sort_key[0:3])
            print('-----------')
            c = 1
            for key in keys:
                t_stamp = projects[key]['l_time'][0].split('-')
                if sort_constraits(t_stamp, check_mode):
                    print_raw_data(key, check_mode, c)
                    c+=1

        # load certain timestamp
        elif check_mode == 'none':
            # get all to february
            print('All projects', sort_key[0:3])
            print('-----------')
            c = 1
            for key in keys:

                # pass id and sort keys
                if sort_constraits('empty_ts_field', sort_key, projects[key]['p_id']):
                    # pay attention - there is SORT_KEY instead CHECK_MODE
                    print_raw_data(key, sort_key, c)
                    c+=1


    elif process == 'structure':

        # generic sorted dict
        sort_projects = {'private': {}, 'public': {}}

        if check_mode in ('month', 'day', 'year', 'all', 'none'):
            # get all to february, rewrite date into organized output
            print('Active projects:  ', sort_key[0:3])
            print('-----------')
            for key in keys:

                # check for timestamp case
                if check_mode == 'none':
                    cons_check = sort_constraits('empty_ts_field', sort_key, projects[key]['p_id'])
                else:
                    t_stamp = projects[key]['l_time'][0].split('-')
                    cons_check = sort_constraits(t_stamp, check_mode)

                # other code
                if cons_check:
                    # split public and private
                    namespace = projects[key]['n_space']
                    if namespace[1] == '.' or namespace[2] == '.' :
                        n_key = 'private'
                    else:
                        n_key = 'public'
                    # set dict record
                    #!!!!!!!!!!!!!!!!!!!!!!
                    # try comprehension
                    try:
                        sort_projects[n_key][namespace].append(projects[key])
                    except:
                        sort_projects[n_key][namespace] = [projects[key]]
            # print to screen
            projects_sorted(sort_projects)        




def projects_sorted(sort_projects):
    # iterate via sorted namespace:
    t = 0
    nspace_keys = sort_projects.keys()
    for n_key in nspace_keys:
        print('==============')
        print('General Namespace:', n_key)
        print('==============')
        print('Nested namespaces:')
        nested_keys = sort_projects[n_key].keys()
        for nn_key in nested_keys:
            c = 1
            print('-----------')
            print(nn_key)
            n_list = sort_projects[n_key][nn_key]
            for x in n_list:
                print('\t', str(c) + '.', x['name'])
                # custom pretty printer
                print('\t\t', '\'Name\':           \'' + x['name'] + '\'')
                print('\t\t', '\'Creation date\':  \'' + x['c_time'] + '\'')
                print('\t\t', '\'Latest build\':  ', x['l_time'])
                print('\t\t', '\'Namespace\':      \'' + x['n_space'] + '\'')
                c+=1
                t+=1

                # get stat
                if d_stat == 'stat':
                    if d_slice[3] == 'none':
                        result = stat_data(x['p_id'], d_slice)
                        # view for result:
                        # { 'info': prj_info, 'pipelines_counter': pipelines_counter, 'jobs_counter': jobs_counter }
                        result['name'] = x['name']
                        summary_list.append(result)
                    else:
                        result = stat_data(x['p_id'], d_slice[3])
                        # view for result:
                        # { 'info': prj_info, 'pipelines_counter': pipelines_counter, 'jobs_counter': jobs_counter }
                        result['name'] = x['name']
                        summary_list.append(result)


    print('===========\nTOTAL COUNT:', t)

def populate_dict() -> None:
    c = 1
    while c < pages_limit:    
        url_path = gitlab_add + '/api/v4/projects' + ctrl_param + str(c)
        fail_status = fetch_data(url_path, c)
        if fail_status:
            break
        c+=1


#print ('Number of arguments:', len(sys.argv), 'arguments.')
#print ('Argument List:', str(sys.argv))
def get_args():

    # set current data
    now = datetime.datetime.now()
    t_list = now.strftime("%Y-%m-%d").split('-')

    # get args
    num_of_args = len(sys.argv)
    args = sys.argv

    default_type  = 'raw'
    default_slice = 'month'
    default_stat  = 'base'

    # count args
    if num_of_args == 4:
        d_stat  = args[3]
        d_type  = args[2]
        d_slice = args[1]
    elif num_of_args == 3:
        d_stat  = default_stat
        d_type  = args[2]
        d_slice = args[1]
    elif num_of_args == 2:
        d_stat  = default_stat
        d_type  = default_type
        d_slice = args[1]
    elif num_of_args == 1:
        d_stat  = default_stat
        d_type  = default_type
        d_slice = default_slice
    else:
        print('ERROR - wrong number of args!')
        sys.exit(2)

    # validate args
    if d_stat not in ['base', 'stat']:
        print('ERROR - wrong data stat parameter -', d_stat)
        sys.exit(2)

    if d_type not in ['raw', 'structure']:
        print('ERROR - wrong data type parameter -', d_type)
        sys.exit(2)

    # we can take datailed time slice
    if len(d_slice.split('-')) == 3:

        ts_list_ = d_slice.split('-')
        # check year
        if not ts_list_[0]:
            d_slice_year = t_list[0]
        elif int(ts_list_[0]) in range(2018, int(t_list[0])+1):
            d_slice_year = int(ts_list_[0])
        else:
            print('ERROR: unknown year field -', ts_list_[0])
            sys.exit(2)
        # check month
        if not ts_list_[1]:
            # don't use default month
            d_slice_month = 'without_month'
        elif int(ts_list_[1]) in range(1, 13):
            d_slice_month = int(ts_list_[1])
        else:
            print('ERROR: unknown month field -', ts_list_[1])
            sys.exit(2)

        # check day
        if not ts_list_[2]:
            # don't use default month
            d_slice_day = 'without_day'
        elif int(ts_list_[1]) in range(1, 32):
            d_slice_day = int(ts_list_[2])
        else:
            print('ERROR: unknown day field -', ts_list_[2])
            sys.exit(2)

        # verificate date rules
        # 1. cannot slice day without a month
        if d_slice_month == 'without_month' and d_slice_day != 'without_day':
            print('ERROR: cannot set day without a month')
            sys.exit(2)


    elif d_slice not in ['month', 'day', 'year', 'all']:
        print('ERROR - wrong data slice parameter -', d_slice)
        sys.exit(2)

    # convert slice into check form
    if d_slice == 'day':
        d_slice_year  = t_list[0]
        d_slice_month = t_list[1]
        d_slice_day   = t_list[2]
        d_srv_info    = 'day'
    elif d_slice == 'month':
        d_slice_year  = t_list[0]
        d_slice_month = t_list[1]
        d_slice_day   = 'without_day'
        d_srv_info    = 'month'
    elif d_slice == 'year':
        d_slice_year  = t_list[0]
        d_slice_month = 'without_month'
        d_slice_day   = 'without_day'
        d_srv_info    = 'year'
    elif d_slice == 'all':
        d_slice_year  = 'all'
        d_slice_month = 'all'
        d_slice_day   = 'all'
        d_srv_info    = 'all'
    else:
        d_srv_info    = 'none'

    # set date slice to list
    d_slice = [ d_slice_year, d_slice_month, d_slice_day, d_srv_info ]

    return d_type, d_slice, d_stat, t_list

def summary_proc(summary_list):

    print('\n\n==============\nSUMMARY:')

    # counting all the jobs and pipelines
    summary_pipelines = 0
    summary_jobs      = 0
    summary_duration  = 0
    
    nested_tabs = '\t\t'
    c = 1
    for item in summary_list:
        if item['jobs_counter'] != 0:
            gen_duration = 0
            print(str(c) + '.', item['name'] + ':')
            c+=1
            for build in item['info']:
                print('\t', build['build_time'], '\t jobs', build['jobs_num'], '\t', 'time ~', str(build['total_duration']) + 'm', '\t', build['branch'])
                summary_duration+=build['total_duration']
                gen_duration+=build['total_duration']
            # counter etc
            print(nested_tabs, '-----------------------')
            print(nested_tabs, 'Total pipelines:', item['pipelines_counter'])
            print(nested_tabs, 'Total jobs:     ', item['jobs_counter'])
            summary_pipelines+=item['pipelines_counter']
            summary_jobs+=item['jobs_counter']

            # generate correct time for duration:
            gen_avr_duration = round(gen_duration/item['jobs_counter'])
            if gen_duration > 60:
                gen_duration = str(round(gen_duration/60)) + ' h'
            else:
                gen_duration = str(gen_duration) + ' m'

            if gen_avr_duration > 60:
                gen_avr_duration = str(round(gen_avr_duration/60)) + ' h'
            else:
                gen_avr_duration = str(gen_avr_duration) + ' m'


            print(nested_tabs, 'Total duration:  ~', gen_duration)
            print(nested_tabs, 'Average duration:  ~', gen_avr_duration)


    # GENERAL SUMMARY

    print('-----------------------')
    print('-----------------------')
    print('Summary projects:       ', c-1)
    print('Summary pipelines:      ', summary_pipelines)
    print('Summary jobs:           ', summary_jobs)
    #print('Average working time:  ~', round(summary_jobs*8/60), 'hours')

    if summary_jobs == 0:
        sys.exit(0)

    # generate correct time for duration:
    summary_avr_duration = round(summary_duration/summary_jobs)
    if summary_duration > 60:

        summary_month_duration = round(summary_duration/24)
        m_counter = 0
        while summary_month_duration > 60:
            summary_month_duration-=60
            m_counter+=1
        summary_month_duration = str(m_counter) + ' hours ' + str(summary_month_duration) + ' min'

        #summary_month_duration = str(round(summary_duration/24/60)) + ' hours'
        h_counter = 0
        while summary_duration > 60:
            summary_duration-=60
            h_counter+=1
        summary_duration = str(h_counter) + ' hours ' + str(summary_duration) + ' min'

        #summary_month_duration = str(summary_duration/24/60) + ' hours'
        #summary_duration       = str(summary_duration/60) + ' hours'
    else:
        summary_month_duration = str(round(summary_duration/24)) + ' min'
        summary_duration       = str(summary_duration) + ' min'

    if summary_avr_duration > 60:
        summary_avr_duration = str(round(summary_avr_duration/60)) + ' hours'
    else:
        summary_avr_duration = str(summary_avr_duration) + ' min'


    print('Total duration:        ~', summary_duration)
    print('Average duration:      ~', summary_avr_duration)
    # Month stat
    #d_slice = [ d_slice_year, d_slice_month, d_slice_day, d_srv_info]
    if d_slice[3] == 'month' or d_slice[2] == 'without_day':
        print('Average day usage:     ~', summary_month_duration)





# code
projects = {}


# get args
d_type, d_slice, d_stat, t_list = get_args()
# summary list for summury data
# summary data for stat key:
if d_stat == 'stat':
    summary_list = []

# control parameters for api query
# main ctrl
gitlab_add  = 'https://gitlab.-----.ru'
#gitlab_add  = 'https://gitlab.com'
# need to ask
priv_token  = '------'

ctrl_param  = '?private_token=' + priv_token + '&per_page=100&page='
#ctrl_param  = '?per_page=100&page='
pages_limit = 200
#pages_limit = 5

# load pages to dict
populate_dict()
# get keys and summ of all records
keys = projects.keys()
total = keys.__len__()

print('TOTAL COUNT:  ', total)
data_sort(process=d_type, sort_key=d_slice)

# summary data for stat key:
if d_stat == 'stat':
    summary_proc(summary_list)
    #print(summary_list)

#data_sort(process='raw', sort_key='all')



