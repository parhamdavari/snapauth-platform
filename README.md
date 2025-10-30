<p align="center">
  <img src="media/snapauth-hero.png" alt="SnapAuth logo" width="640" />
</p>

# SnapAuth Platform

This distribution packages the SnapAuth service alongside FusionAuth and PostgreSQL via Docker Compose.

## Usage

```bash
make up
```

The Makefile runs the published bootstrap container to generate `.env` and `kickstart/kickstart.json`, then brings the stack online via Docker Compose. All artifacts live alongside this file; add `SNAPAUTH_IMAGE` / `BOOTSTRAP_IMAGE` environment variables to override the default GHCR tags.

Notes
- Place the provided image at `media/snapauth-hero.png`. Crop if needed.
- Optional crop (ImageMagick):
  
  ```bash
  # center-crop to square and export optimized PNG
  magick input.png -gravity center -resize 1200x1200^ -extent 1200x1200 \
         -strip -define png:color-type=6 media/snapauth-hero.png
  ```
