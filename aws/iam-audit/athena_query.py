# Adapted from https://github.com/raoofnaushad/AWSathena_s3_python
#  - at https://github.com/raoofnaushad/AWSathena_s3_python/tree/33daf21c6e5960efac8672450156fc806d7e0ebf
#  - License:https://github.com/raoofnaushad/AWSathena_s3_python/blob/33daf21c6e5960efac8672450156fc806d7e0ebf/LICENSE
import time

def query(session, params, role_query, wait = True):
  client = session.client('athena')
  
  # This function executes the query and returns the query execution ID
  print('Starting query execution')
  response_query_execution_id = client.start_query_execution(
    QueryString = role_query,
    QueryExecutionContext = {
      'Database' : params['database']
    },
    ResultConfiguration = {
      'OutputLocation': 's3://' + params['bucket'] + '/' + params['path']
    }
  )

  if not wait:
    return response_query_execution_id['QueryExecutionId']
  else:
    print('Getting query execution')
    response_get_query_details = client.get_query_execution(
      QueryExecutionId = response_query_execution_id['QueryExecutionId']
    )
    status = 'RUNNING'
    iterations = 360

    while (iterations > 0):
      iterations = iterations - 1
      response_get_query_details = client.get_query_execution(
      QueryExecutionId = response_query_execution_id['QueryExecutionId']
      )
      status = response_get_query_details['QueryExecution']['Status']['State']
      print(status)
      
      if (status == 'FAILED') or (status == 'CANCELLED') :
        failure_reason = response_get_query_details['QueryExecution']['Status']['StateChangeReason']
        print(failure_reason)
        return False, False

      elif status == 'SUCCEEDED':
        print('Query execution succeeded')
        location = response_get_query_details['QueryExecution']['ResultConfiguration']['OutputLocation']

        ## Function to get output results
        print('Getting query results')
        response_query_result = client.get_query_results(
          QueryExecutionId = response_query_execution_id['QueryExecutionId']
        )
        result_data = response_query_result['ResultSet']

        return location, result_data
        
      time.sleep(10) # keep this relatively high to prevent request rate exception

    return False
