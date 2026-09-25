#!/bin/bash

cd /home/mde-admin/OceENS

if [ ! -d .venv ]; then
	echo ".venv not found. Installing"
	uv sync --locked
fi

# Les points d'entrée `oceens` et `oceens-summaries-daemon` sont installés dans
# .venv/bin/ par `uv sync` (voir [project.scripts] dans pyproject.toml)
export PYTHONUNBUFFERED=1

if pgrep -f "\.venv/bin/oceens$" > /dev/null; then
	echo "Website already launched"
else

	echo "Launching Website with screen"
	screen -d -m bash -c ".venv/bin/oceens 2> >(tee -a app.error) | tee -a app.log"
fi

if pgrep -f "\.venv/bin/oceens-summaries-daemon$" > /dev/null; then
	echo "Summaries generator already launched"
else

	echo "Launching Summaries generator with screen"
	screen -d -m bash -c ".venv/bin/oceens-summaries-daemon 2> >(tee -a summaries.error) | tee -a summaries.log"
fi
