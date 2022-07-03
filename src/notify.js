const AWS = require('aws-sdk');
const ddb = new AWS.DynamoDB.DocumentClient({ apiVersion: '2012-08-10', region: process.env.AWS_REGION });
const sendMessage = require('./send-message');

const notifyListeners = (clientId, job) => {
  try {
    if (!process.env.AWS_REGION || !process.env.CONNECTION_TABLE_NAME || !process.env.API_ENDPOINT) {
      const msg = 'AWS_REGION, API_ENDPOINT, and CONNECTION_TABLE_NAME environment variables must be set';
      console.error(msg);
      throw new Error(msg);
    }

    let queryResults;

    const queryParams = {
      TableName: process.env.CONNECTION_TABLE_NAME,
      ExpressionAttributeValues: {
        ":v1": {
          S: clientId
        }
      },
      KeyConditionExpression: "clientId = :v1",
      ProjectionExpression: "connectionId",
    };

    queryResults = await ddb.query(queryParams).promise();

    const connectionsForClient = queryResults.Items;
    const messagePromises = connectionsForClient.map(async (connection) => {
      return await sendMessage(connection, job);
    });

    await Promise.all(messagePromises);
    console.log('Notification sent');
    return true;
  } catch (ex) {
    console.error('Error sending notifications: ' + JSON.stringify(err));
    return false;
  }
};

exports.handler = async event => {
  const clientId = "TODO"; // get clientId from event
  try {
    await notifyListeners();
  } catch (err) {
    return { statusCode: 500, body: `Failed to notify for ${clientId}: ` + JSON.stringify(err) };
  }

  return { statusCode: 200, body: `Notified for ${clientId}` };
};
