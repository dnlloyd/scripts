-- Roles by activity
select count(useridentity.sessioncontext.sessionissuer.username) as Count, 
  useridentity.sessioncontext.sessionissuer.username as Role
FROM awsdatacatalog.all_accounts.cloudtrail_logs_all
WHERE account IN ('123456789012')
  AND useridentity.sessioncontext.sessionissuer.type = 'Role'
  AND timestamp LIKE '2023/06/%'
GROUP by useridentity.sessioncontext.sessionissuer.username
ORDER by count DESC
LIMIT 100

-- API calls for a signle role
SELECT eventsource, eventname, count(eventname) as count
FROM awsdatacatalog.all_accounts.cloudtrail_logs_all
WHERE account IN ('123456789012')
  AND useridentity.sessioncontext.sessionissuer.type = 'Role'
  AND timestamp LIKE '2023/06/29'
  AND useridentity.sessioncontext.sessionissuer.username = 'CloudAdmin'
GROUP BY eventsource, eventname
ORDER BY eventsource
LIMIT 100

-- API calls for all roles
SELECT useridentity.sessioncontext.sessionissuer.username as role, eventname, count(eventname) as count
FROM awsdatacatalog.all_accounts.cloudtrail_logs_all
WHERE account IN ('123456789012')
  AND useridentity.sessioncontext.sessionissuer.type = 'Role'
  AND timestamp LIKE '2023/06/%'
GROUP BY useridentity.sessioncontext.sessionissuer.username, eventname
ORDER BY useridentity.sessioncontext.sessionissuer.username, count DESC
LIMIT 1000

-- IAM Actions for a single role
SELECT DISTINCT concat(split_part(eventsource, '.', 1), ':', eventname) as Action
FROM awsdatacatalog.all_accounts.cloudtrail_logs_all
WHERE account IN ('123456789012')
  AND useridentity.sessioncontext.sessionissuer.type = 'Role'
  AND timestamp LIKE '2023/06/%'
  AND useridentity.sessioncontext.sessionissuer.username = 'CloudAdmin'
ORDER BY Action
LIMIT 100





SELECT useridentity.type, 
  useridentity.principalid, 
  useridentity.arn, 
  useridentity.invokedby, 
  useridentity.accesskeyid, 
  useridentity.username, 

  useridentity.sessioncontext.sessionissuer.type,
  useridentity.sessioncontext.sessionissuer.principalid,
  useridentity.sessioncontext.sessionissuer.arn,
  useridentity.sessioncontext.sessionissuer.username,
 
  eventsource, eventname
FROM awsdatacatalog.all_accounts.cloudtrail_logs_all
WHERE account IN ('123456789012')
  AND useridentity.sessioncontext.sessionissuer.type = 'Role'
  AND timestamp LIKE '2023/06/%'
  AND useridentity.sessioncontext.sessionissuer.username = 'AWSReservedSSO_Admin'
LIMIT 5