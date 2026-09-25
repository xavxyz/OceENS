# OcéEns II

Course evaluation platform built for the EPF engineering school.

## Overview

**OcéEns II** lets program managers, facilitators, campus directors and administrators create and manage course evaluation *sondages* for EPF's programs, and lets students answer them. Answers can be exported, visualised, and summarised by an LLM into *synthèses*. The interface is in French and uses EPF's official visual identity.

The documentation is in English; the product's own vocabulary (*sondage*, *synthèse*, on-screen labels) stays in French. [`CONTEXT.md`](CONTEXT.md) defines that boundary.

### Tech stack

| Component | Technology |
|-----------|------------|
| **Framework** | FastAPI (Python 3.12) |
| **Authentication** | Microsoft Entra ID (Azure AD) via OAuth 2.0 / MSAL, Microsoft Graph; dev login without identity provider |
| **Database** | SQLite (via SQLAlchemy + SQLModel) |
| **Templating** | Jinja2 (server-side rendering) |
| **Frontend** | HTML / CSS / JavaScript, no framework |
| **Server** | Uvicorn |
| **Logging** | Python's standard `logging` module |
| **Exports** | Pandas (CSV) |
| **Synthèses** | Separate daemon calling an LLM (`requests-cache`, `markdown-it-py`) |

---

## Quick start

A fresh clone runs locally in [dev mode](#dev-login), with no Entra or LLM credentials. `.env.example` is set up for exactly that.

```bash
git clone <repo-url> OceENS
cd OceENS
cp .env.example .env          # Windows (PowerShell): Copy-Item .env.example .env
```

Then start the application in one of the two ways below and open **http://localhost:8000**. Go to `/dev/login` and pick a user: see [Seed users](#seed-users).

On first start, the application creates the SQLite database (`database/db_oceens.db`, see `LOCAL_DATABASE_DIR`) and fills it with a demo data set if it is empty.

### With Docker Compose

```bash
docker compose up --build
```

`docker compose` refuses to start without a `.env` (`env file .env not found`). The image runs Uvicorn without `--reload`: after changing the code, run `docker compose up --build` again.

The database lives on the host, in `./database/` or in the directory given by `LOCAL_DATABASE_DIR`, mounted at `/app/database`. `./import/` is mounted as well. `.env` is passed to the container at startup and never copied into the image (`.dockerignore`).

### Without Docker

Requires Python 3.12, the version of the Docker image.

```bash
python -m venv .venv
source .venv/bin/activate      # Windows (PowerShell): .venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --reload
```

`python main.py` also starts the application, without reload. On Windows, if PowerShell blocks `Activate.ps1`, call the interpreter by its path instead, as [`docs/smoke-test.md`](docs/smoke-test.md) does.

### Without an LLM key

The application runs normally without an LLM key; only *synthèses* are unavailable. They are produced by a separate daemon (see [Synthèses daemon](#synthèses-daemon)): without a key, each requested *synthèse* is marked as a configuration error. To get a key for the default provider, see [Configuration](#configuration).

---

## Configuration

The application reads its configuration from environment variables. The application and the daemon load `.env` at startup (`load_dotenv()`), without overriding variables already set in the environment. [`.env.example`](.env.example) lists every variable. Copy it to `.env` and fill it in. The table below is the reference.

| Variable | Default | Meaning |
|----------|---------|---------|
| `AUTH_MODE` | `entra` | `entra` (Microsoft Entra ID) or `dev` ([dev login](#dev-login)), case- and whitespace-insensitive. Any other value stops the application at startup (exit code 1). `.env.example` ships `dev`. |
| `DEV_LOGIN_KEY` | unset | `dev` mode only. When set, every dev login must provide it, otherwise `401`. When unset, the dev login is open to anyone. Ignored, with a warning, in `entra`. |
| `SECRET_KEY` | unset | Signs the session cookies: anyone who knows it can forge a session, including an admin one. **Required in `entra`**: when missing or empty, the application logs a critical error and exits at startup (code 1). Optional in `dev`: when missing, a random key is drawn at each start (with a warning), and sessions are lost on restart. Generate one with `python -c "import secrets; print(secrets.token_urlsafe(32))"`. |
| `ALLOWED_DOMAINS` | see meaning | Comma-separated email domains allowed to log in. Unset, it defaults to `epf.fr,epfedu.fr` in `dev`; in `entra`, **no domain is allowed**, so nobody can log in. The same list validates the emails an admin adds and the students enrolled in a *sondage*, where it always defaults to `epf.fr,epfedu.fr`. |
| `ENTRA_CLIENT_ID`, `ENTRA_CLIENT_SECRET`, `ENTRA_TENANT_ID` | unset | Entra ID application, from the Azure portal. Required in `entra`: if one is unset, the application exits at startup (code 1). An empty value is not caught. Unused in `dev`. |
| `REDIRECT_URI` | `https://localhost/auth/callback` | Entra callback URL, registered in the Azure application. The Microsoft logout also sends the user back to it, without its path. Unused in `dev`. |
| `LOCAL_DATABASE_DIR` | `database/` | Directory of the SQLite file `db_oceens.db`, created if needed. A relative path is resolved from the project root. With Docker Compose, it is the host directory mounted into the container. |
| `LLM_API_KEY` | unset | Key of the default LLM provider, *Ollama EPF*. EPF students get their own key at <https://locallm.mde.epf.fr> by logging in with their EPF account. Other providers use their own variables, see [LLM providers](#llm-providers). |
| `RUN_SUMMARIES_DAEMON` | unset | `1`, `true`, `yes` or `on`: the application starts the [*synthèses* daemon](#synthèses-daemon) as a child process and stops it on shutdown. That is how Docker gets a daemon. Leave unset with `launch.sh`, which runs its own daemon. |

Every variable is read once, at process startup: after changing `.env`, restart the application and the daemon.

> [!CAUTION]
> Never commit `.env`. It is listed in `.gitignore`, as are `*.db` files (`database/db_oceens.db`, `cache_llm.db`).

---

## Roles

- `student`: answers the *sondages* they are enrolled in. A user without any role is a student.
- `program_manager:<code>`: manages the *sondages* of their program(s).
- `facilitator:<code>`: runs the *sondages* of their program(s).
- `campus_manager:<campus>`: views results at campus level. The campus must exist in `import/Program_list.csv` (Cachan, Montpellier, Saint-Nazaire, Troyes).
- `admin`: general administration.

A user can hold several roles, each with its own scope (program codes or campuses separated by `;`, for example `program_manager:MDAI4;MDAI5`). `/` sends a user with several roles to a single dashboard, in this order: admin, campus_manager, program_manager, facilitator, student.

### Seed users

The demo data set (`core/seed.py`) contains, among others:

| Email | Roles |
|-------|-------|
| `antoine.gademer@epf.fr` | `admin`, `program_manager:MDAI5` |
| `yassine.gharbi@epfedu.fr` | `admin`, `campus_manager:Montpellier` |
| `arnaud.jousset@epf.fr`, `etienne.gibaud@epf.fr` | `admin` |
| `oceens.facilitator@epf.fr` | `facilitator:MDAI5` |
| `oceens.program-manager@epf.fr` | `program_manager:MDAI5` |
| `oceens.campus-manager@epf.fr` | `campus_manager:Montpellier` |
| `bob.leponge@epfedu.fr`, `peter.parker@epfedu.fr`, `oceens.student07@epf.fr` … `oceens.student20@epf.fr` | none (students) |

`antoine.gademer@epf.fr` and `yassine.gharbi@epfedu.fr` are also admins and land on the admin dashboard; open `/dashboard/program-manager` or `/dashboard/campus-manager` directly for their views. `oceens.facilitator@epf.fr`, `oceens.program-manager@epf.fr` and `oceens.campus-manager@epf.fr` hold a single role each and land on their own dashboard: the first two see the MDAI5 demo *sondage*, the campus manager the Montpellier ones (MDAI4, MDAI5). These users are only seeded into an empty database: delete the database file to get them on an existing install.

---

## Main pages and routes

Pages:

| Route | Description |
|-------|-------------|
| `/` | Home. Redirects a logged-in user to their dashboard. |
| `/login`, `/auth/callback`, `/logout` | Microsoft Entra ID authentication flow. In `dev`, `/login` redirects to `/dev/login` and `/auth/callback` does not exist. |
| `/dev/login` | Dev login, `dev` only: user picker on `GET`, login on `POST` (see [Dev login](#dev-login)). |
| `/dashboard/student` | Student dashboard. |
| `/dashboard/program-manager` | Program manager dashboard. |
| `/dashboard/facilitator` | Facilitator dashboard (also open to `admin`). |
| `/dashboard/campus-manager` | Campus director dashboard. |
| `/dashboard/teachers/analytics` | Satisfaction score per teacher, filterable by school year, semester and program. For `campus_manager` and `program_manager` only, scoped to each one's perimeter. |
| `/dashboard/admin` | Admin dashboard. |
| `/dashboard/survey-create` | Create and configure a *sondage* (`admin`, `program_manager`). |
| `/backend/prompts`, `/backend/prompts/new`, `/backend/prompts/{id}/edit` | LLM prompts: list, creation and edit forms (admin). |
| `/backend/templates` | *Sondage* templates, with their sections and questions (admin). |
| `/backend/providers` | [LLM providers](#llm-providers) (admin). |
| `/backend/llm/prices`, `/backend/llm/costs` | Price grid and [*synthèse* costs](#synthèse-costs) (admin). |

API:

| Route | Description |
|-------|-------------|
| `POST /api/surveys` | Create a *sondage*. |
| `GET`, `POST /api/surveys/{survey_id}` | Questionnaire: display it, submit answers. |
| `DELETE /api/surveys/{survey_id}`, `POST /api/surveys/{survey_id}/delete` | Delete a *sondage*, see [Orphan student cleanup](#orphan-student-cleanup). |
| `POST /api/surveys/{survey_id}/status` | Open (`status=1`) or close (`status=0`) a *sondage*. |
| `GET`, `POST`, `DELETE /api/surveys/{survey_id}/students` | List, enroll (JSON `{"emails": [...]}`) or remove (`?email=`) students. |
| `GET /api/surveys/{survey_id}/export` | CSV export of the answers. |
| `GET /api/surveys/{survey_id}/visualisation` | Answer visualisation. Accepts `?teacher=<name>` to open it filtered on a teacher. |
| `POST /api/surveys/{survey_id}/generate-summaries` | Queue the *synthèses* of a *sondage* for the daemon. |
| `POST /api/surveys/{survey_id}/destroy-summaries` | Delete the generated *synthèses*. |
| `GET /api/surveys/{survey_id}/cost` | Cost of a *sondage*'s *synthèses* (💰 button). |
| `POST /api/users` | Create a user from an email, see [Adding a user by email](#adding-a-user-by-email). |
| `PUT /api/users/{user_id}/role` | Replace all of a user's roles (JSON `{"roles": [...]}`). |
| `POST /api/prompts` | Create a prompt (form). |
| `PUT`, `DELETE /api/prompts/{id}` | Edit or delete a prompt, refused (409) when the prompt is referenced by *synthèses*. |
| `/api/templates`, `/api/sections`, `/api/questions` | CRUD for *sondage* templates, sections and questions. A template must be inactive to be edited. |

Any other unknown path is redirected to `/` (303).

---

## Synthèses daemon

*Synthèses* are generated by `summaries_generator_daemon.py`, a process separate from the web application. The two only communicate through the `summaries` table, used as a queue: the application inserts rows with `http_status = 0`, the daemon processes them one at a time and writes the result back (`200` when done, any other value is a kept failure).

It loops, writes to the database and calls an external service: only run it when needed. Three ways to start it:

- by hand: `python summaries_generator_daemon.py`;
- with the application, through `RUN_SUMMARIES_DAEMON` (see [Configuration](#configuration));
- in production without Docker, through `launch.sh`, which starts the application (`python main.py`) and the daemon in separate `screen` sessions. The script contains the production server's path and virtual environment (`venv/`).

Without a daemon, requested *synthèses* stay queued.

---

## LLM providers

*Synthèses* are generated by an LLM. The provider is **configurable from the interface** (`/backend/providers`, admin only), without touching the code. The default provider is **Ollama EPF** (`https://locallm.mde.epf.fr/ollama`, model `gemma4:26b`, key in `LLM_API_KEY`), created at startup if it does not exist.

### Supported API types

| `api_type` | Covers |
|------------|--------|
| `ollama`    | Ollama servers (local, EPF, third party) |
| `openai`    | OpenAI **and any OpenAI-compatible endpoint**: vLLM, Groq, Mistral, LM Studio… |
| `anthropic` | Claude API (Anthropic) |

### Security principle: no key in the database

The SQLite database is not encrypted and ends up in backups. **No API key is therefore stored in it.** The `llm_providers` table only holds the *name* of the environment variable (`api_key_env`, e.g. `OPENAI_API_KEY`); the value stays in `.env` and is only resolved at call time. The name must match `LLM_*` or `*_API_KEY`, and system secrets (`SECRET_KEY`, `ENTRA_CLIENT_SECRET`…) are refused, so a provider cannot point to them.

### Adding a provider

1. **Add the key to `.env`** under a compliant name (`LLM_*` or `*_API_KEY`):

   ```env
   OPENAI_API_KEY=sk-...
   ```

2. **Restart the application and the daemon**: both only read the environment at startup.

3. **Create the provider** in `/backend/providers` → *+ Nouveau fournisseur*: fill in the name, the API type, the base URL, the variable name (`OPENAI_API_KEY`), and a default model. The **« clé présente / absente »** indicator confirms that the variable is loaded. The **Tester** button lists the provider's models, then sends a one-token generation to confirm that the account can actually generate (see below).

4. **Link a prompt** to the provider: in `/backend/prompts`, a `<select>` picks the provider of a prompt. A prompt without a provider (`provider_id` NULL), or whose provider no longer exists, falls back to Ollama EPF. The model used is the prompt's, or failing that the provider's default model.

> [!NOTE]
> A provider referenced by at least one prompt cannot be deleted, so as not to break those prompts. Deactivating a provider only hides it from the prompt form: prompts already linked to it keep using it.

### Exhausted credit and other provider errors

Each provider reports failures in its own format: exhausted credit is a `429 insufficient_quota` at OpenAI, but a `400 "Your credit balance is too low"` at Anthropic. `services/llm_client.py` maps these responses to categories (`quota`, `rate_limit`, `auth`, `model`, `server`, `unknown`) and derives a readable message from them, in French, for example:

> ⚠️ Crédit ou quota épuisé chez le fournisseur : la clé est valide mais le
> compte ne peut plus générer. Rechargez le compte ou choisissez un autre
> fournisseur. (fournisseur OpenAI, modèle gpt-4o-mini, HTTP 429)

This message is written to `Summary.metadata_text` instead of the raw JSON, so it is visible from the interface when a *synthèse* fails. The provider's raw response stays in the daemon's logs for diagnosis.

> [!IMPORTANT]
> Listing models is not enough: at OpenAI as at Anthropic, `GET /v1/models` still answers perfectly with a zero balance. The **Tester** button therefore also sends a one-token generation (negligible cost): it is the only way to spot exhausted credit **before** launching a campaign of *synthèses*.

---

## Synthèse costs

The cost of each *synthèse* is **measured, not estimated**. At generation time, the daemon records the token counters returned by the provider (`Summary.input_tokens`, `output_tokens`, `model_used`): it is the only chance to capture them, no API lets you ask for them afterwards. The amount is then obtained by combining these counters with the price grid.

> [!NOTE]
> This replaces the former `llm-utils/token-counting/` scripts, which counted the tokens of the **repository's source code** and multiplied them by a hard-coded price. That measure said nothing about the application's actual spending. Tracking now covers the calls actually billed.

### Price grid: `/backend/llm/prices`

Prices live in the database (table `llm_model_prices`) and are editable from the administration: no release is needed to follow a price change or to cover a provider added locally. **All amounts are in euros.** A price has two components, added together:

- a **flat cost per generation**, as a min–max range, for models whose cost is not measured per token: the self-hosted EPF LLM costs 2 to 5 cents per *synthèse*, all included (GPU, electricity, server depreciation);
- a **price per million tokens**, input and output, for commercial providers. Prices published in dollars can be entered in dollars: they are converted to euros once, when saved, at the USD → EUR rate set on the same page (0.92 by default). Changing the rate does not rewrite existing prices.

The cost of a *synthèse* is therefore a range, shown as a single amount when both ends are equal.

Seeded at startup (idempotent: a price corrected by hand is never rewritten):

| Model | Flat cost per generation | Input €/M | Output €/M |
| --- | ---: | ---: | ---: |
| `gemma4:26b` (Ollama EPF, self-hosted) | 0.02–0.05 | 0.00 | 0.00 |
| `claude-opus-5` | 0.00 | 4.60 | 23.00 |
| `claude-sonnet-5` | 0.00 | 2.76 | 13.80 |
| `claude-haiku-4-5` | 0.00 | 0.92 | 4.60 |

The Claude prices are Anthropic's public dollar prices at the default rate. Other providers' prices (OpenAI, Mistral, Groq…) are **to be entered**: they are not guessed. A price attached to a provider wins over a generic price with the same model name; prompts without a provider only match generic prices.

### Where to look

| Where | What |
| --- | --- |
| `/backend/llm/costs` | Global cost, broken down by *sondage* and by model |
| 💰 button on a *sondage* row | Cost of that *sondage*'s *synthèses* |

### What is not priced

Only successful *synthèses* are counted. One cannot be priced when its counters are missing (generated before this feature, or a provider that does not expose them) or when its model has no recorded price. It is then **counted separately**, never estimated nor rounded to zero: a made-up amount would be worse than a missing one, since it would be displayed with the authority of a real amount. The screens say explicitly when a total is partial.

> [!IMPORTANT]
> Tracking starts when the feature went live: *synthèses* generated before have no counters in the database and cannot be priced retroactively.

---

## Logging

Application logs use Python's standard `logging` module, through Uvicorn's loggers, so that the application's messages share the server's format, colours and handlers:

- `logging.getLogger("uvicorn")`, shared as `logger` by `core/dependencies.py` and used by `core/auth.py` and `core/seed.py`, is set to `DEBUG`;
- `logging.getLogger("uvicorn.error")`, used by `core/database.py` and `services/`, keeps Uvicorn's level (`INFO`).

The daemon runs outside Uvicorn and configures its own `INFO` output.

Levels are used according to severity:

| Level | Use |
|-------|-----|
| `DEBUG` | Detailed information useful for development and seeding. |
| `INFO` | Startup, shutdown and normal application operations. |
| `WARNING` | Expected resource missing, or a non-blocking situation. |
| `ERROR` | Failed operation; `logger.exception()` logs at this level and keeps the traceback. |
| `CRITICAL` | Required configuration missing, preventing startup. |

Example:

```python
import logging

logger = logging.getLogger("uvicorn")

logger.info("Operation done")

try:
    risky_operation()
except Exception:
    logger.exception("Operation failed")
```

New diagnostics should use a logger rather than `print()`. Uvicorn's handlers write to `stderr`: redirect it (`2> error.log`) to keep the logs.

---

## Project structure

```
OceENS/
├── main.py                       # FastAPI factory, middlewares and router assembly
├── sondage_loader.py             # Loads a full sondage for export
├── survey_loader_from_xlsx.py    # Imports sondages from an Excel file
├── summaries_generator_daemon.py # Synthèses daemon (separate process)
├── launch.sh                     # Production launch script, without Docker
├── requirements.txt              # Python dependencies
├── Dockerfile                    # Application image
├── docker-compose.yaml           # Local and Docker deployment
├── .env.example                  # Configuration template, to copy to .env
├── .env                          # Environment variables (⚠️ not committed)
├── Template_2025.md              # End-of-semester sondage questions, in Markdown
├── CONTEXT.md                    # Domain glossary
│
├── core/                         # Low-level access and security
│   ├── auth.py                   #   Microsoft Entra ID authentication and dev login
│   ├── database.py               #   SQLite engine and SessionDep dependency
│   ├── security.py               #   Roles, scopes, access control
│   ├── dependencies.py           #   Shared Jinja templates and logger
│   └── seed.py                   #   Initial data and program sync
│
├── models/                       # SQLModel schema, one file per table
│   ├── __init__.py               #   Re-exports every class (see its docstring)
│   └── User.py, Survey.py, ...
│
├── routers/                      # Routes, split by business domain
│   ├── pages.py                  #   Home and role dashboards
│   ├── surveys.py                #   Sondages: CRUD, status, export, visualisation
│   ├── students.py               #   Student enrolment in a sondage
│   ├── users.py                  #   User creation and roles
│   ├── summaries.py              #   Synthèse requests
│   ├── prompts.py                #   Prompt administration
│   ├── survey_templates.py       #   Sondage template administration
│   ├── sections_questions.py     #   Section and question administration
│   └── llm/                      #   LLM administration
│       ├── _access.py            #     Shared access control for the LLM screens
│       ├── providers.py          #     LLM providers (CRUD + connection test)
│       ├── prices.py             #     Price grid per model, USD → EUR rate
│       └── costs.py              #     Global and per-sondage cost
│
├── services/                     # Business logic
│   ├── helpers.py                #   Navigation, statistics, filters, sorting
│   ├── visualisation_data.py     #   Aggregations and visualisation context
│   ├── llm_client.py             #   Multi-provider LLM client (ollama/openai/anthropic)
│   ├── llm_costs.py              #   Synthèse costs (measured tokens × price grid)
│   ├── settings_store.py         #   Settings stored in the database (USD → EUR rate)
│   └── export_csv.py             #   CSV export of the answers
│
├── database/                     # SQLite database (ignored by Git)
│   └── db_oceens.db
│
├── import/                       # Seed data: programs and demo answers
│
├── docs/
│   ├── adr/                      #   Architecture decision records
│   ├── agents/                   #   Configuration of the agent skills
│   └── smoke-test.md             #   Manual smoke test
│
├── llm-utils/                    # LLM tools outside the application
│   └── README.md                 #   (cost tracking moved into the app, see above)
│
├── templates/                    # HTML templates (Jinja2)
│   ├── index.html                #   Home / login page
│   ├── dev_login.html            #   Dev login user picker
│   ├── dashboard/                #   One page per role, plus:
│   │   ├── teachers-analytics.html  # Teacher satisfaction
│   │   ├── survey.html              # Answering a sondage
│   │   ├── survey_create.html       # Creating a sondage
│   │   └── visualisation.html       # Answer visualisation
│   ├── backend/                  #   Administration pages (admin only)
│   │   ├── prompts.html, prompt_form.html
│   │   ├── templates.html        #   Sondage templates, sections, questions
│   │   └── llm/                  #   Providers, prices, costs
│   └── template_parts/           #   Fragments shared between pages (header, modals…)
│
└── static/
    ├── css/                      # One stylesheet per page, plus theme.css, responsive.css…
    ├── js/
    │   └── survey.js
    └── img/
```

---

## Authentication (OAuth 2.0)

With `AUTH_MODE=entra`, authentication goes through **Microsoft Entra ID** with the MSAL library:

```
1. The user clicks "Se connecter"
   → FastAPI generates a random state (UUID, CSRF protection)
   → Redirect to the Microsoft login page

2. The user authenticates at Microsoft
   → Microsoft redirects to /auth/callback with a code + state

3. The server exchanges the code for an access token
   → Fetches the user's profile from Microsoft Graph
   → Checks the email domain against ALLOWED_DOMAINS
   → Creates the user in the database if unknown (as a student)
   → Stores {name, email} in the session
   → Redirects to /, which picks the dashboard

4. On logout (/logout)
   → Clears the session and cookies
   → Logs out at Microsoft
   → Back to the home page
```

The session only holds the user's identity: roles are read from the database on each request. Authentication alone allows no business action: each route then checks the role and the scope (program or campus) through `require_roles()` and its helpers.

---

## Dev login

To work on a fork without an Azure application, the **dev login** (`AUTH_MODE=dev`) lets you log in as any user, with no proof of identity. It must **never** be used in production. Its variables (`AUTH_MODE`, `DEV_LOGIN_KEY`, `SECRET_KEY`, `ALLOWED_DOMAINS`) are described in [Configuration](#configuration).

In `dev` mode, the session cookie is no longer restricted to HTTPS (`http://localhost` works), `/login` redirects to `/dev/login`, `/auth/callback` does not exist, and `/logout` clears the session then goes back to `/`. A warning is logged at startup. A red, non-dismissable banner shows at the top of every page that includes the shared header: it recalls the logged-in address, offers « Changer d'utilisateur » (`/dev/login`), and adds « accès ouvert à tous » when `DEV_LOGIN_KEY` is not set.

`POST /dev/login` expects a form with `email`, `name` (optional) and `key` (when `DEV_LOGIN_KEY` is set). The user is fetched or created as on return from Entra: an unknown email becomes a new student. Without `name`, the display name is built from the email (`bob.leponge@epfedu.fr` → "Bob Leponge"). A new login replaces the session: that is how you switch users.

In a browser, `GET /dev/login` lists the database's users, grouped by role name without scope (a user without a role shows under `student`, a user with several roles under each of them). A click logs in as the chosen user; a free field lets you use another address, with an optional name. When `DEV_LOGIN_KEY` is set, a single key field is shown and used for every login on the page; the key is never stored in the session. Come back to this page to switch users.

```bash
AUTH_MODE=dev DEV_LOGIN_KEY=my-key uvicorn main:app

# Log in as the seed's admin; -c saves the session cookie
curl -i -c cookies.txt \
  -d email=antoine.gademer@epf.fr -d key=my-key \
  http://localhost:8000/dev/login

# Reuse the cookie (-b) for the next requests
curl -b cookies.txt -c cookies.txt -L http://localhost:8000/
```

> [!WARNING]
> With a known `SECRET_KEY` (shared, copied from an example…), anyone who knows it can forge a session cookie and bypass `DEV_LOGIN_KEY`: `dev` mode accepts that, because it is only meant for local use. See `SECRET_KEY` in [Configuration](#configuration).

---

## Notable features

### Teacher analytics

`/dashboard/teachers/analytics` (`campus_manager`, `program_manager`) aggregates the satisfaction score per `(teacher, sondage)` from the `QCU_Satisfaction` answers that carry an `Answer.teacher` (ME sections). The teacher list is sorted with `teacher_sort_key()`, case- and accent-insensitive, and can be filtered by school year, semester, program and teacher.

### Teacher filter in the visualisation

A client-side selector filters the visualisation without reloading: only the chosen teacher's modules stay visible, and the Campus and Program sections are hidden. The page reads `?teacher=<name>` on load to pre-filter itself; links from the analytics pass this parameter, so clicking a teacher's score opens their view directly.

### Sondages imported from Excel

*Sondages* loaded by `survey_loader_from_xlsx.py` have no `QCU_Attendance` question: `services/visualisation_data.py` then uses `satisfaction_responses_count` as the fallback denominator for the teacher score. Teacher names are normalised with `.title()` at import and at aggregation, to merge case variants (`"GADEMER Antoine"` and `"Gademer Antoine"` = a single entry). The template sorts a teacher's questions by `question_id`, which puts charts before free-text answers whatever the insertion order.

### Campus director scope

The `campus_manager` dashboard only shows closed *sondages* with at least one respondent. The questionnaire link and QR code are hidden there (`can_view_survey_link=False`), as are *synthèse* generation and status changes: this role views results without distributing *sondages*. The guard `{% if can_view_survey_link | default(true) %}` leaves the other dashboards unchanged.

### Orphan student cleanup

When a *sondage* is deleted, students who are no longer enrolled in **any other** *sondage* are deleted too, to avoid piling up unused accounts (`services/helpers.py`, `_delete_orphan_students`). A safeguard protects users with a privileged role (`admin`, `program_manager`, `facilitator`, `campus_manager`): a teacher or manager enrolled in a *sondage* is never deleted.

### Adding a user by email

The « Utilisateurs » tab of the admin dashboard has a **« + Ajouter un utilisateur »** button: an email is enough to create the account, with the `student` role (`POST /api/users`). The email is validated (format + allowed domain, see `ALLOWED_DOMAINS`) and duplicates are refused.

---

## Deployment checklist

- [ ] `AUTH_MODE` unset or `entra`
- [ ] `.env` created with the real Entra credentials, `REDIRECT_URI`, `ALLOWED_DOMAINS` and a dedicated `SECRET_KEY` (see [Configuration](#configuration))
- [ ] Valid SSL certificate (Let's Encrypt or equivalent): outside `dev`, session cookies are HTTPS-only
- [ ] Database present (`database/db_oceens.db`, or `LOCAL_DATABASE_DIR`) or Docker volume mounted
- [ ] Environment variables secured, including `LLM_API_KEY` and the other providers' keys
- [ ] **Docker Compose**: `.env` loaded through `env_file`, never copied into the image; `LOCAL_DATABASE_DIR` pointing to the right host directory
- [ ] *Synthèses* daemon running if *synthèses* are used (`RUN_SUMMARIES_DAEMON` with Docker, `launch.sh` without)

---

## Before contributing

The repository has no automated test suite and no CI yet. Before proposing a change, run the static checks and, if the change touches startup, configuration, dependencies or the container, the rest of the [manual smoke test](docs/smoke-test.md). Then test the affected routes by hand on a throwaway SQLite database (never a copy of production), with the relevant roles and *sondage* statuses.

Architecture decisions are recorded in [`docs/adr/`](docs/adr/).

---

## Resources

- [FastAPI](https://fastapi.tiangolo.com/)
- [FastAPI and Uvicorn logging guide](https://apitally.io/blog/fastapi-logging-guide)
- [MSAL Python](https://github.com/AzureAD/microsoft-authentication-library-for-python)
- [Microsoft Graph](https://learn.microsoft.com/en-us/graph/)
- [Jinja2](https://jinja.palletsprojects.com/)
- [SQLAlchemy](https://www.sqlalchemy.org/)
- [SQLModel](https://sqlmodel.tiangolo.com/)
- [Pandas](https://pandas.pydata.org/)

---

**OcéEns team**, EPF
