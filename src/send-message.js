const AWS = require('aws-sdk');

sendMessage = async (connectionId, job) => {
  const apigwManagementApi = new AWS.ApiGatewayManagementApi({
    apiVersion: '2018-11-29',
    endpoint: event.requestContext.domainName + '/' + event.requestContext.stage // TODO
  });

  try {
    await apigwManagementApi.postToConnection({ ConnectionId: connectionId, Data: job }).promise();
  } catch (e) {
    if (e.statusCode === 410) {
      console.log(`Found stale connection, deleting ${connectionId}`);
      await closeConnection(connectionId);
    } else {
      throw e;
    }
  }

  return true
}
