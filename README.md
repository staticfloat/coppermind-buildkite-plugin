# coppermind-buildkite-plugin
> Memoize buildkite steps based on treehashes

## Dependencies

Relies upon `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` (and optionally `S3_DEFAULT_REGION`) to be defined in your environment.
To securely store secrets in your `pipeline.yml` file, use [`cryptic`](https://github.com/staticfloat/cryptic-buildkite-plugin/).
This plugin composes nicely with [`forerunner`](https://github.com/staticfloat/forerunner-buildkite-plugin/) to allow for templated, memoized jobs.

## Basic Usage

```
steps:
  - label: ":hammer: run benchmark"
    key: "benchmark"
    plugins:
      - JuliaCI/julia#v1:
          version: 1
      - staticfloat/coppermind#v2:
          inputs:
            # We are sensitive to the source code of this package changing
            - src/**.jl
            # We are sensitive to our overall dependencies changing
            - ./*.toml
          s3_prefix: s3://julialang-buildkite-artifacts/scimlbenchmarks
    commands: julia --project=. benchmark.jl
    artifacts:
      - pdf/**.pdf
```
