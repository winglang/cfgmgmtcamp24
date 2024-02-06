bring cloud;
bring expect;
bring http;
bring "./hitcounter.w" as h;

class Shortener {
  mapping: cloud.Bucket;
  pub url: str;
  hitcounter: h.HitCounter;

  new() {
    let api = new cloud.Api()  as "data_plane";
    let mapping = new cloud.Bucket() as "mapping";
    this.hitcounter = new h.HitCounter();
    this.mapping = mapping;
    this.url = api.url;
    
    api.get("/:alias", inflight (req) => {
      let alias = req.vars.get("alias");
      let target = mapping.get(alias);
      this.hitcounter.hit(alias);
      log("redirecting {alias} to ?");
      return {
        status: 307,
        headers: {
          location: target
        }
      };
    });
  }

  pub inflight create(alias: str, target: str) {
    this.mapping.put(alias, target);
  }

  pub inflight stats(): Map<num> {
    return this.hitcounter.query();
  }
}

let s = new Shortener() as "s2";


test "happy flow" {
  s.create("wing", "https://winglang.io");
  let response = http.get("{s.url}/wing", redirect: http.RequestRedirect.MANUAL);
  expect.equal(307, response.status);
  let location = response.headers.get("location");
  expect.equal("https://winglang.io", location);

  http.get("{s.url}/wing", redirect: http.RequestRedirect.MANUAL);
  http.get("{s.url}/wing", redirect: http.RequestRedirect.MANUAL);

  log(Json.stringify(s.stats()));
}

