# Protocol Security Review Questions — SNARKeling TreasureHunt

## Basic Info

| Protocol Name                                | SNARKeling TreasureHunt                                                    |
| -------------------------------------------- | -------------------------------------------------------------------------- |
| Website                                      | https://codehawks.cyfrin.io/c/2026-04-snarkeling                           |
| Link To Documentation                        | https://github.com/CodeHawks-Contests/2026-04-snarkeling                   |
| Key Point of Contact (Name, Email, Telegram) |                                                                            |
| Link to Whitepaper, if any (optional)        | N/A                                                                        |

## Code Details

| Link to Repo to be audited                              | https://github.com/CodeHawks-Contests/2026-04-snarkeling |
| ------------------------------------------------------- | -------------------------------------------------------- |
| Commit hash                                             | `aed232c`                                                |
| Number of Contracts in Scope                            | 2 (+ 2 Noir circuit files)                               |
| Total SLOC for contracts in scope                       | 176 nSLOC (Solidity); Noir circuits additional           |
| Complexity Score                                        |                                                          |
| How many external protocols does the code interact with | 1 (Barretenberg/Noir ZK verifier — generated artifact)   |
| Overall test coverage for code under audit              | Partial — original suite covers happy paths only         |

### In Scope Contracts

```
contracts/src/
#-- TreasureHunt.sol        (165 nSLOC)
#-- Verifier.sol            (11 nSLOC)
circuits/src/
#-- main.nr                 (ZK circuit)
#-- tests.nr                (circuit tests)
```

## Protocol Details

TreasureHunt is an on-chain treasure hunt game. Players solve off-chain physical/puzzle hunts to discover secrets, then generate Barretenberg/Noir ZK proofs and call `claim()` to receive 10 ETH each. The contract holds up to 100 ETH (10 treasures × 10 ETH).

| Current Status                                                      | Contest / pre-production                                                 |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| Is the project a fork of the existing protocol                      | Yes                                                                      |
| Specify protocol (only if Yes for prev question)                    | CodeHawks-Contests/2026-04-snarkeling (original contest repo)            |
| Does the project use rollups?                                       | No                                                                       |
| Will the protocol be multi-chain?                                   | No (single chain deployment)                                             |
| Specify chain(s) on which protocol is/ would be deployed            | EVM-compatible chain (Solidity 0.8.27 / Shanghai EVM)                    |
| Does the protocol use external oracles?                             | No                                                                       |
| Does the protocol use external AMMs?                                | No                                                                       |
| Does the protocol use zero-knowledge proofs?                        | Yes — Barretenberg UltraHonk / Noir circuit                              |
| Which ERC20 tokens do you expect to interact with smart contracts   | None — ETH only                                                          |
| Which ERC721 tokens do you expect to interact with smart contracts? | None                                                                     |
| Are ERC777 tokens expected to interact with protocol?               | No                                                                       |
| Are there any off-chain processes (keeper bots etc.)                | Yes                                                                      |
| If yes to the above, please explain                                 | Players run `bb` (Barretenberg) locally to generate ZK proofs off-chain  |

## Protocol Risks

| Should we evaluate risks related to centralization?                          | Yes — owner controls pause, verifier updates, and emergency withdrawal |
| ---------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Should we evaluate the risks of rogue protocol admin capturing user funds?   | Yes                                                                    |
| Should we evaluate risks related to deflationary/ inflationary ERC20 tokens? | No — ETH only                                                          |
| Should we evaluate risks due to fee-on-transfer tokens?                      | No                                                                     |
| Should we evaluate risks due to rebasing tokens?                             | No                                                                     |
| Should we evaluate risks due to the pausing of any external contracts?       | No                                                                     |
| Should we evaluate risks associated with external oracles (if they exist)?   | No                                                                     |
| Should we evaluate risks related to blacklisted users for specific tokens?   | No                                                                     |
| Is the code expected to comply with any specific EIPs?                       | No                                                                     |
| If yes for the above, please share the EIPs                                  | N/A                                                                    |

## Known Issues

| Issue #1 | Stub `Verifier.sol` always returns `true` — intended to be replaced by generated Barretenberg verifier before deployment |
| -------- | ------------------------------------------------------------------------------------------------------------------------ |

## Previous Audits and Reports

| How many previous audits | 1 (this engagement)                                                           |
| ------------------------ | ----------------------------------------------------------------------------- |
| Link to Audit Report(s)  | [2026-04-snarkeling-audit.md](2026-04-snarkeling-audit.md) / [PDF](2026-04-snarkeling-audit.pdf) |

## Resources

### Flow Charts / Design Docs

- [Original contest repo](https://github.com/CodeHawks-Contests/2026-04-snarkeling)

### Explainer Videos

- …

### Articles / Blogs

- …

## The Rekt Test

1. **Do you have all actors, roles, and privileges documented?**
   Yes — Owner and Player roles are documented. Owner: fund, pause/unpause, update verifier, emergency withdraw, withdraw after hunt ends. Player: call `claim()` with valid ZK proof.

2. **Do you keep documentation of all the external services, contracts, and oracles you rely on?**
   Partially — Barretenberg/Noir ZK backend is referenced but not pinned in a dependency manifest accessible to reviewers.

3. **Do you have a written and tested incident response plan?**
   No.

4. **Do you document the best ways to attack your system?**
   No — audit report now covers this.

5. **Do you perform identity verification and background checks on all employees?**

6. **Do you have a team member with security defined in their role?**

7. **Do you require hardware security keys for production systems?**

8. **Does your key management system require multiple humans and physical steps?**

9. **Do you define key invariants for your system and test them on every commit?**
   No — invariant tests were added as part of this audit; they were not present prior.

10. **Do you use the best automated tools to discover security issues in your code?**
    Slither and Aderyn were run as part of this audit. No automated tooling was in the CI pipeline originally.

11. **Do you undergo external audits and maintain a vulnerability disclosure or bug bounty program?**
    This CodeHawks contest is the first external audit. No bug bounty program exists.

12. **Have you considered and mitigated avenues for abusing users of your system?**
    No — multiple critical issues found during audit allow full prize pool drain without valid proofs.

## Post Deployment Planning

1. **Are you planning on using a bug bounty program? Which one/where?**

2. **What is your monitoring solution? What are you monitoring for?**

3. **Who is your incident response team?**
