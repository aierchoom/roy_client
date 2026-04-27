# Client System Modules

`lib/system/` contains focused implementation helpers that support services,
views, and providers without becoming UI widgets or broad app facades.

- `service_manager/`: small helpers used by `ServiceManager`.

Prefer this folder for pure rules, persistence helpers, and narrow coordinators
that would otherwise make a service file handle too many responsibilities.
