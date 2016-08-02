# Description:
#
#   Viewing luigi stats
#
# Commands:
#   hubot luigi stats - Show overall stats
#   hubot luigi show <query> - List RUNNING/PENDING/DONE tasks
#   hubot luigi search <query> - Search task by task id
#   hubot luigi resources - Luigi resource summary
#   hubot luigi refresh resources - Luigi refresh resources from disk
#   hubot luigi workers - Luigi worker summary
#   hubot luigi worker <salt> - Show worker details
#   hubot luigi blockers - Show worker details
#   
# Configuration:
#   HUBOT_LUIGI_ENDPOINT - luigi scheduler api endpoint, like 'http://localhost:8082/api/'
#   HUBOT_LUIGI_BLOCKERS_CRONTAB - crontab to run blocker alerts
#   HUBOT_LUIGI_BLOCKERS_THRESHOLD - alert threshold
#   HUBOT_LUIGI_BLOCKERS_ROOM - the room to post to for blocker alert
#
# URLS:
#   https://github.com/spotify/luigi/
#
# Author:
#   interskh


luigiApiEndpoint = process.env.HUBOT_LUIGI_ENDPOINT

luigiBlockersCrontab = process.env.HUBOT_LUIGI_BLOCKERS_CRONTAB
luigiBlockersThreshold = process.env.HUBOT_LUIGI_BLOCKERS_THRESHOLD
luigiBlockersAlertRoom = process.env.HUBOT_LUIGI_BLOCKERS_ROOM

module.exports = (robot) ->

  blockersAlert = ->
    console.log "running cronjob - getting luigi blockers stats"
    robot.http(luigiApiEndpoint + "blockers")
      .query(data: JSON.stringify({priority_sum: true, min_blocked: parseInt(luigiBlockersThreshold, 10), limit: 10}))
      .get() (err, res, body) ->
        try
          ret = JSON.parse body
          if ret.response.length > 0
            results = []
            for w in ret.response
              results.push(w.blocked + " " + w.display_name)
            console.log "luigi blockers \n" + results.join("\n")
            robot.messageRoom luigiBlockersAlertRoom, "hi team, there seems to be some slackers in the pipeline: \n" + results.join("\n")
        catch error
          console.log body
          console.log error

  if luigiBlockersCrontab
    console.log("enabling luigi blockers")
    cronJob = require('cron').CronJob
    tz = 'America/Los_Angeles'
    try
      new cronJob(luigiBlockersCrontab, blockersAlert, null, true, tz)
    catch error
      console.log error

  robot.respond /luigi statu?s(\s*)$/i, (msg) ->
    callLuigiTaskList msg, "RUNNING", (res) ->
      running = numberOfTask(res)
      callLuigiTaskList msg, "PENDING", (res) ->
        pending = numberOfTask(res)
        callLuigiTaskList msg, "FAILED", (res) ->
          failed = numberOfTask(res)
          callLuigiTaskList msg, "DISABLED", (res) ->
            disabled = numberOfTask(res)
            msg.send running + " jobs running, " + pending + " jobs pending, " + failed + " jobs failed, " + disabled + " jobs disabled"

  robot.respond /luigi show( all)? (.*)(\s*)/i, (msg) ->
    status = msg.match[2].toUpperCase()
    callLuigiTaskList msg, status, (res) ->
      results = []
      for t in sortTask(res)
        results.push(formatTask(t[0], t[1]))
      sendLimitedResult(msg, results, 20)

  robot.respond /luigi search (.*)(\s*)/i, (msg) ->
    callLuigiTaskSearch msg, msg.match[1], (res) ->
      results = []
      counts = {}
      for status, d of res
        counts[status] = Object.keys(res[status]).length
        for t in sortTask(d)
          results.push(status + " " + formatTask(t[0], t[1]))
      if results.length > 0
        counts_message = "summary: "
        for status, count of counts
          counts_message += count + " " + status + ", "
        msg.send counts_message
      sendLimitedResult(msg, results, 20)

  robot.respond /luigi resources(\s*)/i, (msg) ->
    callLuigiResources msg, (res) ->
      results = []
      for r in sortResource(res)
        resource = r[0]
        d = res[resource]
        results.push(resource + " : " + d.used + "/" + d.total)
      msg.send results.join("\n")

  robot.respond /luigi workers(\s*)/i, (msg) ->
    callLuigiWorkers msg, (res) ->
      results = []
      for w in res
        results.push(w.salt + " " + w.first_task + " [" + w.workers + "]  " + w.num_running + " running, " + w.num_pending + " pending")
      msg.send results.join("\n")

  robot.respond /luigi worker (.*)(\s*)/i, (msg) ->
    search = msg.match[1]
    callLuigiWorkers msg, (res) ->
      for w in res
        if w.salt == search
          msg.send(w.salt + " " + w.first_task + " [" + w.workers + "]  " + w.num_running + " running, " + w.num_pending + " pending, " + w.num_uniques + " uniq pending")
          if w.num_running > 0
            tasks = []
            for task_id, task of w.running
              tasks.push(task_id)
            msg.send("running tasks: " + tasks.join(", "))

  robot.respond /luigi refresh resources(\s*)/i, (msg) ->
    callLuigiUpdateResources msg, (res) ->
      callLuigiResources msg, (res) ->
        results = []
        for r in sortResource(res)
          resource = r[0]
          d = res[resource]
          results.push(resource + " : " + d.used + "/" + d.total)
        msg.send results.join("\n")

  robot.respond /luigi blockers(\s*)/i, (msg) ->
    callLuigiBlockers msg, (res) ->
      results = []
      for w in res
        results.push(w.blocked + " " + w.display_name)
      msg.send results.join("\n")

sendLimitedResult = (msg, results, n=0) ->
  if results.length > 0
    if n > 0
      if results.length > n
        msg.send results.slice(0, n).join("\n") + "... and " + (results.length - n) + " more"
      else
        msg.send results.slice(0, n).join("\n")
    else
      msg.send results.join("\n")

callLuigiTaskList = (msg, jobType, cb) ->
  msg.http(luigiApiEndpoint + "task_list")
    .query(data: JSON.stringify({status: jobType, upstream_status: ""}))
    .get() (err, res, body) ->
      try
        ret = JSON.parse body
        cb ret.response
      catch error
        console.log body
        console.log error
        cb {}

numberOfTask = (res) ->
  if res.hasOwnProperty("num_tasks")
    return res.num_tasks
  else
    return Object.keys(res).length

callLuigiTaskSearch = (msg, str, cb) ->
  msg.http(luigiApiEndpoint + "task_search")
    .query(data: JSON.stringify({task_str: str}))
    .get() (err, res, body) ->
      try
        ret = JSON.parse body
        cb ret.response
      catch error
        console.log body
        console.log error
        cb {}

callLuigiResources= (msg, cb) ->
  msg.http(luigiApiEndpoint + "resources")
    .get() (err, res, body) ->
      try
        ret = JSON.parse body
        cb ret.response
      catch error
        console.log body
        console.log error
        cb {}

callLuigiUpdateResources= (msg, cb) ->
  msg.http(luigiApiEndpoint + "update_resources")
    .get() (err, res, body) ->
      try
        ret = JSON.parse body
        cb ret.response
      catch error
        console.log body
        console.log error
        cb {}

callLuigiWorkers= (msg, cb) ->
  msg.http(luigiApiEndpoint + "worker_list")
    .get() (err, res, body) ->
      try
        ret = JSON.parse body
        cb ret.response
      catch error
        console.log body
        console.log error
        cb {}

callLuigiBlockers = (msg, cb) ->
  msg.http(luigiApiEndpoint + "blockers")
    .query(data: JSON.stringify({priority_sum: true, min_blocked: 101, limit: 10}))
    .get() (err, res, body) ->
      try
        ret = JSON.parse body
        cb ret.response
      catch error
        console.log body
        console.log error
        cb {}

sortTask = (taskDict) ->
  # tasks in taskDict should be in the same status
  sortable = []
  for task_id, task of taskDict
    status = task.status
    sortable.push([task_id, task])
  if status == 'RUNNING'
    sortable.sort (a,b) -> a[1].time_running - b[1].time_running
  else
    sortable.sort (a,b) -> a[1].start_time - b[1].start_time

sortResource = (resourcesDict) ->
  sortable = []
  for resource, d of resourcesDict
    if d.total == 0
      n = 0
    else if d.used == 0
      n = 0.1 / d.total
    else
      n = d.used / d.total
    sortable.push([resource, n])
  sortable.sort (a,b) -> a[1] - b[1]

formatTask = (task_id, task) ->
  if task.status == 'RUNNING'
    formatTime(task.time_running) + " " + task_id + " p=" + task.priority
  else
    formatTime(task.start_time) + " " + task_id + " p=" + task.priority

formatTime = (ts) ->
  new Date(Math.floor(ts*1000)).toLocaleString()
