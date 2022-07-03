const closeConnection = require('./close-connection');

exports.handler = async event => {
  try {
    await closeConnection(event.requestContext.connectionId);
  } catch (err) {
    return { statusCode: 500, body: `Failed to disconnect ${connectionId}: ` + JSON.stringify(err) };
  }

  return { statusCode: 200, body: `Disconnected ${connectionId}` };
};
