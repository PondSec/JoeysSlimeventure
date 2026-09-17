# Steam-art builder

Run the builder from the repository root. The licensed poster source is kept
outside the repository, so provide it explicitly:

```sh
JOEY_STEAM_POSTER_PATH=/absolute/path/to/poster.png \
  python3 tools/marketing/build_steam_assets.py
```

Generated files are written to `marketing/steam/generated/`.
