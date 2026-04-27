# Service Manager System Helpers

This folder holds focused helpers used by `ServiceManager`.

- `default_sync_server_url.dart`: platform default sync server URL.
- `sync_server_url_store.dart`: persisted sync server URL reads, writes, and
  normalization.
- `password_tools.dart`: password generation and strength facade.
- `vault_dump_coordinator.dart`: encrypted vault dump import/export only.

Keep `ServiceManager` as the orchestration facade. Put pure rules, persistence
helpers, and small coordinators here when they can stand alone.
