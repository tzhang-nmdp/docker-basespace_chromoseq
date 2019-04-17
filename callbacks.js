function launchSpec(dataProvider)
{
    var ret = {
        //commandLine: [ "/usr/bin/java", "-Dconfig.file=/opt/files/basespace_cromwell.config", "-jar", "/opt/cromwell-36.jar", "run", "-t", "wdl", "-i", "/opt/files/inputs.json", "/opt/files/Chromoseq.v8.cromwell34.hg38.wdl"],
        //containerImageId: "johnegarza/chromoseq",
        //commandLine: ["cat", "/tester.txt"],
        //commandLine: ["/bin/bash", "-c", "ls -lR data"],
        //commandLine: ["/bin/bash", "-c", "/bin/cat data/input/AppSession.json"],
        //commandLine: ["cat", "data/input/AppSession.json"],
        //commandLine: ['find', '/'],
        commandLine: ['python', '-u', '/opt/files/driver.py'],
        containerImageId: "johnegarza/chromoseq",
        Options: [ "bsfs.enabled=true" ]
    };
    return ret;
}

// example multi-node launch spec
/*
function launchSpec(dataProvider)
{
    var ret = {
        nodes: []
    };
    
    ret.nodes.push({
        appSessionName: "Hello World 1",
        commandLine: [ "cat", "/illumina.txt" ],
        containerImageId: "basespace/demo",
        Options: [ "bsfs.enabled=true" ]
    });
    
    ret.nodes.push({
        appSessionName: "Hello World 2",
        commandLine: [ "cat", "/illumina.txt" ],
        containerImageId: "basespace/demo",
        Options: [ "bsfs.enabled=true" ]
    });
    
    return ret;
}
*/

/* 
function billingSpec(dataProvider) {
    return [
    {
        "Id" : "insert product ID here",
        "Quantity": 1.0
    }];
}
