---
name: renewal_risk_review
description: Prepare for renewal and executive sponsor calls by combining renewal risk from the Renewal Desk agent with escalated-case status from the Escalation Desk agent. Also handles renewal discount, playbook, and save plan requests.
---

# Renewal Risk Review

Use this skill when the user asks which renewals need attention, why an account's renewal is at risk, to prepare for a renewal or executive sponsor call, about a renewal discount or the playbook, or to save a save plan or assign an escalation owner.

## Tools

### Renewal_Desk

Customer Success's agent. It ranks and scores renewal risk, answers from the renewal playbook, and saves approved save plans.

**When to use**: First, for every request about renewals, risk, discounts, the playbook, or save plans.

**Required inputs**: The user's request in their own words, including the account name and any time window.

### Escalation_Desk

Support's agent. It reports an account's escalated and high-priority cases and assigns executive owners and target dates.

**When to use**: After `Renewal_Desk`, when its answer lists escalated cases, or when the user is preparing for a sponsor call or asks about escalations.

**Required inputs**: The account name, and the user's request.

## Steps

1. Call `Renewal_Desk` with the user's request.
2. If step 1 shows escalated cases for one account, or the user is preparing for a sponsor call, call `Escalation_Desk` for that account.
3. Reply with the `Renewal_Desk` answer, then an **Escalations** section with the `Escalation_Desk` table. Say which escalated cases still need an executive owner or a target date.
4. When either agent asks a question, ask the user and send the reply to that same agent.

## Guidelines

- Keep each agent's tables, scores, and citations unchanged. Do not query records or answer policy questions yourself.
- Changes happen only in the agent that owns them, and only after the user says yes: save plans in `Renewal_Desk`, escalation owners in `Escalation_Desk`.
