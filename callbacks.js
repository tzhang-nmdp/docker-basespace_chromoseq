function launchSpec(dataProvider)
{
    var ret = {
        commandLine: ['bash', '/opt/files/logging_helper.sh'],
        containerImageId: "mgibio/basespace_chromoseq:latest",
        Options: [ "bsfs.enabled=true" ]
    };
    return ret;
}

/* 
function billingSpec(dataProvider) {
    return [
    {
        "Id" : "insert product ID here",
        "Quantity": 1.0
    }];
}
*/
