# frozen_string_literal: true

# Insist on the tzinfo-data gem instead of the system zoneinfo database, so
# TZInfo::Timezone.all_identifiers is the same on every machine. Without this,
# TZInfo silently falls back to reading the OS's zoneinfo files if the gem
# ever fails to load.
TZInfo::DataSource.set(:ruby)
