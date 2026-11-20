# Design agents for AI Skills in Coworker

Example code for the Salesforce Developers blog post "Design Agents for AI Skills in Coworker". One **Agentforce Coworker skill orchestrates two Employee Agents**, each written in Agent Script and owned by a different team. The skill decides when, who, and in what order; the agents own the Apex, Flow, and Data 360 tools.

Org requirements: Coworker (`AISearchUser`, `AISearchAdmin`), the AI Skill permission sets, and Data 360.

## Architecture

```
Coworker
 └─ Skill: Renewal Risk Review  (skill/renewal-risk-review/SKILL.md)
     ├─ tool Renewal_Desk → Employee Agent "Renewal Desk" (Customer Success)
     │    ├─ apex://ListUpcomingRenewals          rank renewals by risk
     │    ├─ apex://GetAccountRenewalRisk         score + factors for one account
     │    ├─ flow://Create_Renewal_Save_Plan      write, needs confirmation
     │    └─ AnswerQuestionsWithKnowledge         Data 360 library "Customer Success Playbooks"
     └─ tool Escalation_Desk → Employee Agent "Escalation Desk" (Support), called only when there are escalations
          ├─ apex://GetAccountEscalations         escalated + high-priority cases
          └─ flow://Assign_Escalation_Owner       write, needs confirmation
```

Coworker skills can't call Apex or Flow directly, so the Employee Agent is the bridge. Each concept lives in one place:

| Concept | Lives in |
|---|---|
| Risk weights and the one account query | `RenewalRiskService.cls` |
| Policy (steps per band, discount approvals, escalation rules) | Data Library docs in `data-library/` |
| How to use the tools, the brief format, guardrails | `Renewal_Desk.agent` |
| When Coworker should use this, and who to delegate to | `SKILL.md` |

## What is in the org

| Piece | Status |
|---|---|
| Fields: `Account.Licensed_Seats__c`, `Active_Users_30d__c`, `Last_QBR_Date__c`; `Opportunity.Renewal_Risk__c`, `Save_Plan__c` | Deployed |
| Apex: `RenewalRiskService`, `ListUpcomingRenewals`, `GetAccountRenewalRisk`, `RenewalRiskServiceTest` (all tests pass, 94–100% coverage) | Deployed, and tested through `/actions/custom/apex/...` |
| Flow: `Create_Renewal_Save_Plan` (active) | Deployed, and tested through `/actions/custom/flow/...` |
| Data Library `Customer_Success_Playbooks` (`<library-id>`, RAG config `ARFPC_<library-id>`) | Indexed. A Data 360 `hybrid_search` returns the right passages. |
| Employee Agent `Escalation_Desk` (Agent Script) | **Published and active (v1).** Compile and validate are clean. A live preview passed the read, assign, and confirm turns. |
| Apex `AccountResolver` (shared account lookup for both agents), `GetAccountEscalations` (+ test); Flow `Assign_Escalation_Owner`; fields `Case.Executive_Owner__c`, `Case.Target_Resolution_Date__c` | Deployed and tested |
| Agent access to both agents | In permission set `Renewal_Risk_Demo` (`agentAccesses`) |
| Employee Agent `Renewal_Desk` (Agent Script) | **Published and active (v1).** Local compile and `sf agent validate` are clean. A simulated preview passed every demo turn. Live preview passed the list, risk, and save turns with real Apex and Flow. |
| Skill `renewal_risk_review_2` (created in Skill Builder) | v1 is active (single-agent). v2 is a draft with the two-agent orchestration body from `SKILL.md`. |
| Permission set `Renewal_Risk_Demo` and the Coworker/Skill permission sets | Assigned to the admin user |
| Demo data: 8 accounts (`AccountNumber` `CSD-*`), 8 FY27 renewals, 7 cases | Seeded |

## Remaining steps (UI only, no API)

1. **Data space access.** Without it, the agent's playbook search fails with `INSUFFICIENT_ACCESS_OR_READONLY` ("you don't have access to the data space used by the assigned data library"). Go to Setup, then Permission Sets, then **Renewal Risk Demo**, then **Data Cloud Data Space Management**, then Edit, add `default`, and Save. Inserting a `SetupEntityAccess` row for the data space is rejected.
2. **Skill Builder.** Open **Renewal Risk Review** in Agentforce Studio under **Skills**. Paste the body of `SKILL.md` into the instructions, choose **Agentforce Coworker** as where the skill is available, add `Renewal_Desk` and `Escalation_Desk` under **Resources → Tools**, then **Save** and **Publish**. Share it, or use **Distribute to "My Skills"**.

Until step 1 is done, the agent shows the score and factors, then says the playbook couldn't be reached. It doesn't invent steps.

After agent edits: validate, deploy the bundle, then run `sf agent publish authoring-bundle --json --api-name Renewal_Desk -o <your-org>` and `sf agent activate --json --api-name Renewal_Desk -o <your-org>`.

## Demo flow in Coworker

1. **"Which renewals need attention in the next 90 days?"** Expect 6 renewals: Harborview Bank and Cedar & Pine Insurance High, Orbital Freight and Bluepeak Health Medium, Quillstone Media and Northwind Logistics Low.
2. **"Why is Harborview at risk, and what should we do?"** Expect five factors (renewal timing +10, 38% seats +35, 2 high-priority cases +20, an escalation +15, a stale QBR +15), playbook steps cited from Data 360, and a proposed save plan.
3. **"Can we offer them a 12% discount?"** Answered from the Concessions policy: CFO approval above 10%, and with utilization under 50% the preferred concession is rightsizing plus an adoption workshop.
4. **"Yes, save that plan."** The agent asks for confirmation, then the Flow sets `Renewal_Risk__c` and `Save_Plan__c` and creates an owner task.

What to show developers:
- `SKILL.md`: delegation in a few lines.
- `Renewal_Desk.agent`: `target: "apex://..."` and `"flow://..."`, plus `require_user_confirmation: True` on the write action.
- The `@InvocableMethod` and `@InvocableVariable` descriptions in the Apex classes.

## Reset and cleanup

- Re-seed on recording day, because dates are relative to today: `sf apex run -f scripts/cleanup.apex -o <your-org>`, then `sf apex run -f scripts/seed.apex -o <your-org>`
- Agent loop: edit the `.agent` file, run `sf agent validate authoring-bundle --json --api-name Renewal_Desk`, then `sf project deploy start --json --metadata AiAuthoringBundle:Renewal_Desk`, then preview with `sf agent preview start --json --authoring-bundle Renewal_Desk`.
- Remove the Data Library: `sf agent adl delete -o <your-org> --library-id <library-id>`

## Project notes

- `published-snapshots/` holds the read-only `aiAgents` and `aiAgentDefinitionVersions` that `sf agent publish` retrieves. They live outside `force-app` because older CLIs can't resolve those types. The `.agent` files are the source of truth.
- Skills aren't supported by the Metadata API yet, so `skill/renewal-risk-review/SKILL.md` is the source you paste into Skill Builder in each org.
- To check a Data Library, use `hybrid_search(TABLE(<index DMO>), '<query>', '', N)`. `COUNT(*)` on the chunk DMO returns 0 even when search works.
