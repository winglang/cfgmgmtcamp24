bring "cdk8s" as cdk8s;
bring "cdk8s-plus-27" as plus;
bring fs;

// lets create a volume that contains our app.
let appData = new plus.ConfigMap();
appData.addDirectory("./src");

let appVolume = plus.Volume.fromConfigMap(this, "ConfigMap", appData);

// lets create a deployment to run a few instances of a pod
let deployment = new plus.Deployment(
  replicas: 3,
);

// now we create a container that runs our app
let appPath = "/var/lib/app";
let port = 80;
let container = deployment.addContainer({
  image: "node:14.4.0-alpine3.12",
  command: ["node", "index.js", "{port}"],
  port: port,
  workingDir: appPath,
});

// make the app accessible to the container
container.mount(appPath, appVolume);

// finally, we expose the deployment as a load balancer service and make it run
deployment.exposeViaService(serviceType: plus.ServiceType.LOAD_BALANCER);
