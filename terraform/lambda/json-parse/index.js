console.log("Loading function");

exports.handler = (event, context, callback) => {
  console.log("Node version:", process.version);
  console.log("Received event:", JSON.stringify(event));

  const records = event.records.map(record => {
    const data = (Buffer.from(record.data, "base64")).toString("utf8");
    const parsedData = JSON.parse(data);
    const recursiveParsedData = { ...parsedData, log: JSON.parse(parsedData.log) };

    console.log("Parsed data:", JSON.stringify(recursiveParsedData));

    return {
      recordId: record.recordId,
      result: "Ok",
      data: Buffer.from(JSON.stringify(recursiveParsedData) + "\n", "utf8").toString("base64")
    };
  });

  console.log("Return records:", JSON.stringify(records));

  return callback(null, { records });
}
