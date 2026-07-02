/// Base URL for JIRA issues. The issue key is appended to build the browse
/// link (e.g. `https://jira.elbek-vejrup.dk/browse/AU2-1234`). The REST API
/// host is derived from this via `Uri.parse(jiraBaseUrl).host`, so this const
/// is the single source of truth for both the browser link and API calls.
const String jiraBaseUrl = 'https://jira.elbek-vejrup.dk/browse/';
