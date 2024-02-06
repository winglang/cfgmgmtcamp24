bring containers;
bring cloud;
bring http;

pub class HitCounter {
  url: str;

  new() {
    let service = new containers.Workload(
      name: "hitcounter",
      image: "./hit-counter",
      port: 3000,
      public: true,
    );

    this.url = unsafeCast(service.publicUrl);
  }

  pub inflight hit(alias: str) {
    let url = "{this.url}/{alias}";
    log("posting to {url}");
    let r = http.post("{url}");
    assert(r.ok);
  }

  pub inflight query(): Map<num> {
    let r = http.get(this.url);
    assert(r.ok);
    return QueryResult.parseJson(r.body).counts;
  }
}

struct QueryResult {
  counts: Map<num>;
}