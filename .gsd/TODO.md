# TODO.md — Backlog

> Items captured during development for later attention.

## High Priority
- [ ] Fix `email_service.py` to use async `aiosmtplib` instead of blocking `smtplib`
- [ ] Remove duplicate `get_db()` from `db/session.py` (use one in `core/deps.py`)
- [ ] Add Alembic for database migrations

## Medium Priority
- [ ] Restrict CORS origins for production
- [ ] Add structured logging (replace `print()` statements)
- [ ] Complete Twilio SMS provider implementation

## Low Priority
- [ ] Clean up `init_db.py` — remove `sys.path.insert` hack
- [ ] Add request/response logging middleware
