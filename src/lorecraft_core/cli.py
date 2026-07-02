"""CLI utilities."""

import asyncio

import typer
from rich.console import Console
from rich.table import Table

from lorecraft_core import __version__
from lorecraft_core.health import run_health

app = typer.Typer(name="lorecraft", help="LoreCraft Core CLI")
console = Console()


@app.command()
def version():
    """Print version."""
    console.print(f"lorecraft-core {__version__}")


@app.command()
def health():
    """Run installation and service health checks."""
    checks = asyncio.run(run_health())
    table = Table(title="LoreCraft Core Health")
    table.add_column("Check")
    table.add_column("Status")
    for name, ok in checks.items():
        table.add_row(name, "[green]ok[/green]" if ok else "[red]fail[/red]")
    console.print(table)


if __name__ == "__main__":
    app()
