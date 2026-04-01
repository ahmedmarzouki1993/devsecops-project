# alembic/env.py — Alembic migration environment configuration
#
# WHY Alembic?
#   SQLAlchemy's create_tables() is fine for tests and first-time setup,
#   but in production you can't just DROP and recreate tables — you'd lose data.
#   Alembic tracks schema changes as versioned migration files (like git for the DB).
#   Each migration has an upgrade() and downgrade() function, so you can safely
#   evolve the schema and roll back if something goes wrong.
#
# HOW autogenerate works:
#   `alembic revision --autogenerate -m "description"`
#   Alembic compares your SQLAlchemy models (target_metadata) to the current DB schema
#   and generates the migration SQL automatically. Always review the generated file!
#
# HOW to run migrations:
#   alembic upgrade head        # apply all pending migrations
#   alembic downgrade -1        # roll back the last migration
#   alembic history             # list all migrations
#   alembic current             # show current applied migration

import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from alembic import context

# Import our models' Base so autogenerate can diff against them
from app.db_models import Base
# Import settings to read DATABASE_URL from environment
from app.config import settings

# Alembic Config object — access to alembic.ini values
config = context.config

# Set up Python logging from alembic.ini
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# This is what alembic compares against to autogenerate migrations.
# It sees all tables registered on Base (ItemORM, UserORM, etc.)
target_metadata = Base.metadata

# Override the sqlalchemy.url from alembic.ini with the value from our settings.
# This means DATABASE_URL env var controls where alembic runs migrations —
# same as the app itself. No separate alembic.ini database config needed.
config.set_main_option("sqlalchemy.url", settings.database_url)


def run_migrations_offline() -> None:
    """Run migrations without a live DB connection — outputs SQL to stdout.

    Useful for generating SQL scripts to review before applying (e.g., DBA review).
    Run with: alembic upgrade head --sql
    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations against a live DB connection (the normal path).

    NullPool is used so alembic doesn't keep a connection open after migrating.
    """
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,  # Don't pool — alembic is a one-shot CLI tool
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
