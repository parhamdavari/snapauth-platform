# SnapAuth Platform

SnapAuth Platform is a lean bootstrap environment that pairs the SnapAuth service with FusionAuth and PostgreSQL so you can stand up a complete authentication stack in minutes.

Dependencies: Docker (with Compose) and Make.

Usage:
- Clone this repository.
- Run `make up`.

The bootstrap process generates the required `.env` secrets and starts every container, giving you a ready-to-use identity provider backed by SnapAuth with zero manual configuration.
