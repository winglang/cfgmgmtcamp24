bring cloud;
bring "./hitcounter.w" as hc;

// url shortener

// control plane:
// POST / <-- creates a new alias {alias, target}
// GET /stats <-- returns stats for our hit counter

// data plane:
// GET /:alias <-- returns 301

let mapping = new cloud.Bucket() as "mapping";

let h = new hc.HitCounter();

let data = new cloud.Api() as "data plane";
data.get("/:alias", inflight (req) => {
  let alias = req.vars.get("alias");
  let target = mapping.get(alias);
  h.hit(alias);
  return {
    status: 307,
    headers: {
      location: target
    }
  };
});

struct Request {
  alias: str;
  target: str;
}

let control = new cloud.Api() as "control plane";

control.post("/", inflight (req) => {
  if let body = Request.tryParseJson(req.body) {
    mapping.put(body.alias, body.target);
    return {
      status: 200,
      body: "{data.url}/{body?.alias}"
    };
  }

  return {status: 400};  
});

control.get("/stats", inflight (req) => { 
  return { status: 200, body: Json.stringify(h.query()) };
});

// --------------------------------------------

bring http;
bring expect;

test "happy flow" {
  let target = "https://google.com";
  let r1 = http.post("{control.url}/", body: Json.stringify({
    alias: "wing",
    target: target
  }));

  assert(r1.ok);
  let short_url = r1.body;

  let result = http.get(short_url, redirect: unsafeCast("manual"));
  let location = result.headers.get("location");
  expect.equal(target, location);
}