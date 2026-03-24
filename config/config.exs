import Config

config :sprite_ex,
  source_root: Path.expand("../test/fixtures/icons", __DIR__),
  build_path: Path.expand("../_build/sprites", __DIR__),
  public_path: "/assets/sprites"
