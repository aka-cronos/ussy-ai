# Uzzy

Uzzy shows the subscription quotas of AI services and when they reset.

## Language

**Subscription quota**:
A usage limit a provider applies to a subscription over a given period. Distinct from monetary spend and from billed API consumption.
_Avoid_: Balance, credits, consumption (without saying what is measured).

**Used quota**:
The part of a subscription quota already consumed within its period.
_Avoid_: Spend, cost.

**Remaining quota**:
The part of a subscription quota still available within its period.
_Avoid_: Available money, balance.

**Reset**:
The moment, given by the provider, when a subscription quota renews.
_Avoid_: Top-up, session renewal.

**Last valid reading**:
A subscription quota's data from the last valid query for a specific account, together with the time of that query. After a failed refresh it is stale and does not confirm the current quota.
_Avoid_: Current quota (when it could not be refreshed), another account's data.

**Quota period**:
The interval a quota's usage and limit belong to. Quotas with different periods are independent even when they belong to the same provider.
_Avoid_: Calendar month (when it is a billing cycle), combined period.

**Quota bag**:
A share of a subscription the provider names and limits on its own, e.g. Cursor's «Cursor Models» and «Other Models» within one billing cycle. Bags of the same period are still separate quotas.
_Avoid_: Total, combined quota.

**Calculated value**:
A quota value derived from other valid data of that same quota, account, unit and period, rather than reported directly by the provider.
_Avoid_: Provider-reported value (when it is calculated), estimate (for an exact calculation).

**Session**:
The sign-in an official app (Claude Code, Codex CLI, Cursor) keeps on this Mac, which Uzzy reuses read-only to query quotas. It can be missing, expired (rejected by the provider), inaccessible (access denied by the user), in an unknown format, or without subscription quotas (e.g. Codex CLI signed in with an API key).
_Avoid_: Login, account (the account is the identity behind a session), the 5-hour quota period.

**Account**:
The provider identity behind a session, e.g. Claude Code's account UUID. Every last valid reading belongs to the account whose session produced it.
_Avoid_: User, profile, session (the session is how Uzzy reaches the account).

**Uncertain identity**:
The state of a session whose account cannot be verified, e.g. because its identity is missing.
_Avoid_: Unknown account (as if it were a distinct account), anonymous session.
