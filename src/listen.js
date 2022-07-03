// endpoint to listen for updates
const AWS = require('aws-sdk');
const ddb = new AWS.DynamoDB.DocumentClient({ apiVersion: '2012-08-10', region: process.env.AWS_REGION });

exports.handler = async (event) => {
  if (!process.env.AWS_REGION || !process.env.CONNECTION_TABLE_NAME || !process.env.API_ENDPOINT) {
    const msg = 'AWS_REGION, API_ENDPOINT, and CONNECTION_TABLE_NAME environment variables must be set';
    console.error(msg);
    throw new Error(msg);
  }

  const connectionId = event.requestContext.connectionId;
  const clientId = "TODO"; // get clientId from event

  const putParams = {
    TableName: process.env.CONNECTION_TABLE_NAME,
    Item: {
      connectionId,
      clientId
      // TODO ttl
    }
  };

  try {
    await ddb.put(putParams).promise();
  } catch (err) {
    return {
      statusCode: 500,
      body: `Failed while ${connectionId} tried to start listening for client ${clientId}` + JSON.stringify(err)
    };
  }

  return { statusCode: 200, body: `${connectionId} began listening for client ${clientId}` };
};
