bring cloud;
bring expect;
bring http;
bring "./hitcounter.w" as h;

struct Alias {
  target: str;
  alias: str;
}

class UrlShortener {
  mapping: cloud.Bucket;
  pub url: str;
  hitcounter: h.HitCounter;

  new() {
    this.hitcounter = new h.HitCounter();
    let mapping = new cloud.Bucket() as "mapping";
    let api = new cloud.Api() as "data_plane";
    this.url = api.url;

    api.get("/:alias", inflight (req) => {
      let alias = req.vars.get("alias");
      log("redirecting {alias} to ??");
      let target = mapping.get(alias);
      this.hitcounter.hit(alias);
      return {
        status: 307,
        headers: {
          location: target
        }
      };
    });
  
    this.mapping = mapping;
  }

  pub inflight shorten(opts: Alias) {
    this.mapping.put(opts.alias, opts.target);
  }

  pub inflight stats(): Map<num> {
    return this.hitcounter.query();
  }
}

let shortner = new UrlShortener();

test "happy flow" {
  shortner.shorten(alias: "wing", target: "https://winglang.io");
  shortner.shorten(alias: "cfg", target: "https://cfgmgmtcamp.org");

  let check = (alias: str, target: str) => {
    let r1 = http.get("{shortner.url}/{alias}", redirect: http.RequestRedirect.MANUAL);
    expect.equal(r1.status, 307);
    let location = r1.headers.get("location");
    log(location);
    expect.equal(target, location);
  };

  check("wing", "https://winglang.io");
  check("cfg", "https://cfgmgmtcamp.org");
  check("cfg", "https://cfgmgmtcamp.org");
  check("cfg", "https://cfgmgmtcamp.org");

  log(Json.stringify(shortner.stats()));
}

new cloud.Function(inflight () => {
  log("bigstuff");
}, memory: 2048);