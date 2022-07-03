const AWS = require('aws-sdk');
const ddb = new AWS.DynamoDB.DocumentClient({ apiVersion: '2012-08-10', region: process.env.AWS_REGION });

closeConnection = async (connectionId) => {
  const deleteParams = {
    TableName: process.env.CONNECTION_TABLE_NAME,
    Key: {
      connectionId
    }
  };

  await ddb.delete(deleteParams).promise();
};
