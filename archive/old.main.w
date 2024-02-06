bring cloud;
bring expect;
bring http;

let api = new cloud.Api();
let redirects = new cloud.Bucket() as "redirects";

struct CreateRedirect {
  alias: str;
  target: str;
}

api.post("/", inflight (req) => {
  if let r = CreateRedirect.tryParseJson(req.body) {
    if redirects.exists(r.alias) {
      return { status: 407, body: "{r.alias} already exists" };
    }

    redirects.put(r.alias, r.target);
  } else {
    return { status: 400 };
  }
});

api.get("/:alias", inflight (req) => {

  let alias = req.vars.get("alias");
  let target = redirects.get(alias);

  return {
    status: 301,
    headers: {
      location: target
    }
  };
});


test "happy flow" {
  http.post("{api.url}/", body: Json.stringify(CreateRedirect {
    alias: "fb",
    target: "https://facebook.com"
  }));

  let response = http.get("{api.url}/fb", redirect: unsafeCast("manual"));
  let location = response.headers.get("location");
  expect.equal("https://facebook.com", location);
}

