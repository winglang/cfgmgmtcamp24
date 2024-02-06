bring cloud;
bring expect;
bring http;
bring "./hitcounter.w" as hc;

let hitcount = new hc.HitCounter();
let mapping = new cloud.Bucket() as "mapping";
let data = new cloud.Api() as "data plane";

data.get("/:alias", inflight (r) => {
  let alias = r.vars.get("alias");
  let target = mapping.get(alias);
  hitcount.hit(alias);
  return {
    status: 301,
    headers: {
      location: target
    }
  };
});

let control = new cloud.Api() as "control plane";

control.post("/aliases", inflight (r) => {
  if let body = Json.tryParse(r.body) {
    let alias = body.get("alias").asStr();
    if mapping.exists(alias) {
      return {status:401, body: "already exists"};
    }

    let target = body.get("target").asStr();
    let url = "{data.url}/{alias}";
    mapping.put(alias, target);
    return { status: 200, body: url };
  }
  
  return { status: 400 };
});

control.get("/hits", inflight () => {
  return {
    status: 200,
    body: Json.stringify(hitcount.query()),
    headers: {
      "content-type": "application/json"
    }
  };
});

control.get("/", inflight () => {
  return {
    status: 200,
    headers: {
      "content-type": "text/html"
    },
    body: "<p>hello, world!</p>"
  };
});

test "happy path" {
  let r1 = http.post("{control.url}/aliases", body: Json.stringify({
    target: "https://foo.bar",
    alias: "foobar"
  }));

  assert(r1.ok);
  let url = r1.body;

  let r2 = http.get(url, redirect: unsafeCast("manual"));
  let location = r2.headers.get("location");
  log(location);
  expect.equal("https://foo.bar", location);
}

test "alias already exists" {
  let r1 = http.post("{control.url}/aliases", body: Json.stringify({
    target: "https://foo.bar",
    alias: "foobar"
  }));

  assert(r1.ok);

  let r2 = http.post("{control.url}/aliases", body: Json.stringify({
    target: "https://foo.bar",
    alias: "foobar"
  }));

  assert(r2.status == 401);
}