# coppermind-buildkite-plugin
> Memoize buildkite steps based on treehashes

## Dependencies

Requires `aws` to be installed, for uploading to/downloading from AWS.
Also relies upon `BUILDKITE_S3_ACCESS_KEY_ID`, `BUILDKITE_S3_SECRET_ACCESS_KEY` and `BUILDKITE_S3_DEFAULT_REGION` to be defined in your environment block.
To securely store secrets in your `pipeline.yml` file, use a setup similar to that of the [JuliaGPU ecosystem](https://github.com/JuliaGPU/buildkite/).
This plugin composes nicely with the [`forerunner` plugin](https://github.com/staticfloat/forerunner-buildkite-plugin/) to allow for templated, memoized jobs.

## Basic Usage

```
steps:
  - label: ":hammer: {PATH}"
    key: "benchmark"
    plugins:
      - JuliaCI/julia#v1:
          version: 1.6
      - staticfloat/coppermind:
          inputs:
            # We are sensitive to the source code of this package changing
            - src/**.jl
            # We are sensitive to our overall dependencies changing
            - ./*.toml
          outputs:
            - pdf/**.pdf
          s3_prefix: s3://julialang-buildkite-artifacts/scimlbenchmarks
    commands: julia --project=. benchmark.jl
```

Advanced usage includes multiple steps that can re-use eachothers artifacts through the `input_from` argument, see [this example](https://github.com/SciML/SciMLBenchmarks.jl/blob/4d642fbcd590cac843fe4c34121deca604ef6b2e/.buildkite/run_benchmark.yml#L53-L61) for more.
