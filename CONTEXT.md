# OcéEns

EPF's course evaluation platform: *sondages* are created per program, students answer them, and the answers are exported, visualised and summarised into *synthèses*.

## Language

The documentation is written in English. The product's own vocabulary stays in French, because the application's interface is French:

- *sondage*: a course evaluation survey (`Survey` in the code);
- *synthèse*: an LLM-generated summary of a *sondage*'s free-text answers (`Summary` in the code);
- interface labels, quoted as they appear on screen (« Changer d'utilisateur », **Tester**).

Everything else, including code identifiers, is English.

### Authentication

**Dev login** (`AUTH_MODE=dev`, titled « Connexion de développement » in the interface):
Login without an identity provider: you pick a user's email address and are logged in as that user, with no proof of identity. It only exists when `AUTH_MODE=dev` and must never be used in production.
_Avoid_: impersonation, spoofing, fake login
