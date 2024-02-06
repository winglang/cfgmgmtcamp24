exports.Platform = class {
  target = "tf-aws";

  // newApp(appProps) { }
  // newInstance(type, scope, id, props) { }
  // preSynth(app) { }
  // postSynth(config) { }

  validate(config) {
    for (const [name, props] of Object.entries(config.resource.aws_lambda_function)) {
      const path = props["//"].metadata.path;
      if (props.memory_size && props.memory_size > 1024) {
        throw new Error(`Function '${path}' requires ${props.memory_size} MiB which is above the limit of 1024 MiB`);
      }
    }
  }
};