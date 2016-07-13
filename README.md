# Hubot Luigi Script

Interact with luigi central scheduler, to get job status, worker status, etc.


## Installation

Add the package `hubot-luigi` entry to the `packages.json` file
(you may need to create this file).

    "dependencies": {
      "hubot-luigi": "1.0.x"
    }

Run the following command to make sure the module is installed.

    #npm install hubot-luigi

To enable the script, add the `hubot-luigi` entry to the `external-scripts.json`
file (you may need to create this file).

    ["hubots-luigi"]


## Configuration
* HUBOT_LUIGI_ENDPOINT - specify luigi scheduler api endpoint, like 'http://localhost:8082/api/'

## Usage Examples
### stats
    user1> hubot luigi stats
    hubot> 8 jobs running, 1315 jobs pending, 76 jobs failed, 5737 jobs disabled


### show
    user1> hubot luigi show pending
    hubot> Wed Sep 02 2015 13:27:36 GMT-0700 (PDT) Task(param1=value) p=50
           Wed Sep 02 2015 13:27:36 GMT-0700 (PDT) WrapperTask(run=all_tasks) p=50
           Wed Sep 02 2015 13:27:36 GMT-0700 (PDT) HadoopHourlyJob(jar=process_logs.jar, time=2015-08-30T00) p=100
           Wed Sep 02 2015 13:27:36 GMT-0700 (PDT) ScpTask(file=filename.csv, target=server) p=10

Show can be run with any task status, including pending, running, disabled, failed. If more than 20
tasks are to be shown, it will truncate the list and state how many more there are.


### search
    user1> hubot luigi search Hadoop
    hubot> DONE Sun Aug 30 2015 00:12:21 GMT-0700 (PDT) HadoopHourlyJob(jar=process_logs.jar, time=2015-08-30T01) p=100
           DONE Sun Aug 30 2015 00:12:21 GMT-0700 (PDT) HadoopHourlyJob(jar=process_logs.jar, time=2015-08-30T00) p=100
           DONE Sun Aug 30 2015 00:12:21 GMT-0700 (PDT) HadoopHourlyJob(jar=process_logs.jar, time=2015-08-30T02) p=100
           DONE Sun Aug 30 2015 01:12:18 GMT-0700 (PDT) HadoopHourlyJob(jar=analytics_reports.jar, time=2015-08-30T00) p=15

Search matches the query against task ids and is case sensitive. Results are truncated as in show.


### resources
    user1> hubot luigi resources
    hubot> impala: 3/4
           hadoop_xl: 2/2
           mysql_access: 0/5

This will only show resources that are defined in luigi.cfg and not ones that are created in response
to task scheduling.


### refresh resources
    user1> hubot luigi refreshresources
    hubot> impala: 3/2
           hadoop_xl: 2/3
           mysql_access: 0/4

This causes the scheduler to dynamically reload the resource constraints from luigi.cfg. The current
resource usage is then displayed, which can violate the new constraints until existing jobs have had
a chance to finish.


### workers
    user1> hubot luigi workers
    hubot> 781608491 AllTasksFrontFill(days=1, end_time=2015-09-02T13:30) [10]  1 running, 637 pending
           377433553 AllTasksFrontFill(days=1, end_time=2015-09-02T13:00) [10]  6 running, 486 pending
           042179238 AllTasksFrontFill(days=1, end_time=2015-09-01T16:00) [10]  0 running, 46 pending
           208362896 AllTasksFrontFill(days=5, end_time=2015-09-01T03:00) [10]  2 running, 496 pending

### worker
    user1> hubot luigi worker 208362896
    hubot> 208362896 AllTasksFrontFill(days=5, end_time=2015-09-01T03:00) [10]  3 running, 496 pending, 478 unique pending

           running tasks: NumberedTask(n=7), NumberedTask(n=18), NumberedTask(n=3)
