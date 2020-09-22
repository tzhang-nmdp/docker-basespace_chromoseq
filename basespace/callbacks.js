function launchSpec(dataProvider)
{
    var ret = {
        commandLine: ['bash', '/opt/files/logging_helper.sh'],
        containerImageId: "docker.illumina.com/mgibio/chromoseq@sha256:25559e850a21c3c9308ef145646a7e0327d8538704cd199fe45db72358e68a13",
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
