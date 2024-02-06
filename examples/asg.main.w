bring "@cdktf/provider-aws" as aws;

let myGroup = new aws.placementGroup.PlacementGroup(
  name: "myGroup",
  strategy: "cluster"
);

new aws.autoscalingGroup.AutoscalingGroup(
  minSize: 5,
  maxSize: 2,
  desiredCapacity: 4,
  healthCheckGracePeriod: 300,
  healthCheckType: "ELB",
  placementGroup: myGroup.id,
);