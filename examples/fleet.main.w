bring "@cdktf/provider-aws" as aws;
bring fs;
bring http;

class Fleet {
  hosts: Array<str>;

  new(size: num) {
    let hosts = MutArray<str>[];

    for i in 0..size {

      let sg = new aws.securityGroup.SecurityGroup(
        ingress: [
          { fromPort: 80, toPort: 80, protocol: "tcp", cidrBlocks: ["0.0.0.0/0"] },
          { fromPort: 443, toPort: 443, protocol: "tcp", cidrBlocks: ["0.0.0.0/0"] },
        ],
        egress:  [
          { fromPort: 0, toPort: 0,  protocol: "-1",  cidrBlocks: ["0.0.0.0/0"] 
        }]
      ) as "security-group-{i}";

      let host = new aws.instance.Instance(
        ami: "ami-0277155c3f0ab2930",
        instanceType: "t2.micro",
        userData: fs.readFile("./userdata.sh"),
        associatePublicIpAddress: true,
        securityGroups: [sg.name]
      ) as "host-{i}";

      hosts.push(host.publicIp);
    }
  
    this.hosts = hosts.copy();
  }

  pub inflight request(shard: num, urlpath: str, options: http.RequestOptions?): http.Response {
    let host = this.hosts.at(shard);
    return http.fetch("{host}/{urlpath}", options);
  }
}

let f = new Fleet(1);

bring cloud;
new cloud.Function(inflight () => {
  let response = f.request(0, "/hello");
  log(response.body);
});