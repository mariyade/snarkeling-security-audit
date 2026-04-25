# SNARKeling TreasureHunt — Security Audit

**Auditor:** Mariya Danilova 
**Date:** April 2026  
**Contest:** [CodeHawks — 2026-04-snarkeling](https://github.com/CodeHawks-Contests/2026-04-snarkeling)  
**Original codebase:** forked from [CodeHawks-Contests/2026-04-snarkeling](https://github.com/CodeHawks-Contests/2026-04-snarkeling)

📄 [Audit Report (PDF)](2026-04-snarkeling-audit.pdf) | [Audit Report (Markdown)](2026-04-snarkeling-audit.md)

---

## What This Repository Is

This is a **security audit** of the SNARKeling TreasureHunt protocol — an on-chain treasure hunt where players submit Barretenberg/Noir ZK proofs to claim ETH rewards.

The original contest code is preserved unmodified. Everything listed under [What I Added](#what-i-added) is my own audit work.

---

## Protocol Summary

TreasureHunt holds 100 ETH (10 × 10 ETH rewards). A player who physically finds a treasure generates a ZK proof that they know the secret behind one of 10 pre-committed treasure hashes, then calls `claim()` with the proof, the hash, and a recipient address. If the proof verifies on-chain, the contract pays 10 ETH to the recipient.

---

## Findings Summary

| ID | Title | Severity |
|----|-------|----------|
| [H-1](#h-1) | Stub verifier accepts any proof — full prize pool drainable | High |
| [H-2](#h-2) | Double-spend check uses wrong mapping key — same treasure claimable 10 times | High |
| [H-3](#h-3) | Treasure secrets trivially brute-forceable from public circuit data | High |
| [H-4](#h-4) | Duplicate entry in `ALLOWED_TREASURE_HASHES` — only 9 unique treasures exist | High |
| [H-5](#h-5) | Negative field elements in `Prover.toml.example` — 6 of 10 treasures unclaimable | High |
| [M-1](#m-1) | CEI pattern violated in `emergencyWithdraw` and `withdraw` | Medium |
| [L-1](#l-1) | `updateVerifier` missing address(0) check — can brick the contract | Low |
| [L-2](#l-2) | `Claimed` event emits `msg.sender` instead of `recipient` | Low |
| [L-3](#l-3) | `nonReentrant` applied to only one of three ETH-sending functions | Low |
| [L-4](#l-4) | `recipient` public input unconstrained in ZK circuit | Low |
| [I-1](#i-1) | 11 custom errors declared but never used | Informational |
| [I-2](#i-2) | Mixed error-handling styles | Informational |
| [I-3](#i-3) | Unspecific Solidity pragma | Informational |
| [I-4](#i-4) | PUSH0 opcode — EVM version compatibility | Informational |
| [I-5](#i-5) | Unused state variable `_treasureHash` | Informational |
| [I-6](#i-6) | `bb` missing from devcontainer — build pipeline incomplete | Informational |

**Full report:** [2026-04-snarkeling-audit.md](2026-04-snarkeling-audit.md)

---

## Critical Bug Highlight — H-2

The double-spend guard on line 88 reads from `claimed[_treasureHash]` — an immutable state variable that is **never assigned**, always `bytes32(0)` — while the write on line 104 correctly uses the calldata parameter `treasureHash`.

```solidity
// TreasureHunt.sol:35 — never initialized, always bytes32(0)
bytes32 private immutable _treasureHash;

// Line 88 — WRONG: checks bytes32(0) slot, not the claimed treasure
if (claimed[_treasureHash]) revert AlreadyClaimed(treasureHash);

// Line 104 — correct write, but the check above never triggers
_markClaimed(treasureHash);
```

Result: any non-zero treasure hash can be claimed repeatedly until `claimsCount` hits `MAX_TREASURES`, draining all 100 ETH.

---

## What I Added

All files below were created as part of this audit. The original contest code is untouched.

```
contracts/test/
├── TreasureHuntExploits.t.sol     ← PoC tests reproducing H-1, H-2, missing onlyOwner, L-1, L-2
├── TreasureHuntFuzz.t.sol         ← Fuzz tests: recipient validation, fund amounts, withdraw bounds
├── TreasureHuntInvariants.t.sol   ← Invariant tests including one that FAILS to prove H-2
└── handlers/
    └── TreasureHuntHandler.sol    ← Foundry invariant handler with ghost variables

2026-04-snarkeling-audit.md        ← Full audit report (PDF also available)
slither.config.json                ← Slither static analysis configuration
```

---

## Running the Tests

```bash
forge install foundry-rs/forge-std
forge build
```

**Unit tests (original + audit):**
```bash
forge test --match-path "contracts/test/TreasureHunt.t.sol" -v
```

**Exploit PoCs — each test should PASS, proving the bug is real:**
```bash
forge test --match-path "contracts/test/TreasureHuntExploits.t.sol" -v
```

**Fuzz tests:**
```bash
forge test --match-path "contracts/test/TreasureHuntFuzz.t.sol" -v
```

**Invariant tests:**
```bash
# Safety invariants — should all pass
forge test --match-test "invariant_claimsCount|invariant_owner|invariant_verifier|invariant_ghost" -v

# This one FAILS on purpose — Foundry finds the H-2 counterexample
forge test --match-test "invariant_doubleSpendProtection_FAILS_PROVING_H2" -vvvv
```

---

## Repository Structure

```
contracts/
├── src/
│   ├── TreasureHunt.sol       ← original (contains bugs documented above)
│   └── Verifier.sol           ← original stub verifier (always returns true)
└── test/
    ├── TreasureHunt.t.sol     ← original contest tests
    ├── TreasureHuntExploits.t.sol    ← [ADDED] PoC exploits
    ├── TreasureHuntFuzz.t.sol        ← [ADDED] fuzz tests
    ├── TreasureHuntInvariants.t.sol  ← [ADDED] invariant tests
    └── handlers/
        └── TreasureHuntHandler.sol   ← [ADDED] invariant handler

circuits/
└── src/
    ├── main.nr                ← original Noir ZK circuit
    └── tests.nr               ← original circuit tests

2026-04-snarkeling-audit.md   ← [ADDED] full audit report
```

---

## Original Protocol Documentation

<details>
<summary>Setup instructions from the original contest repo</summary>

**System requirements:** Linux or WSL2, Foundry, Noir/nargo (1.0.0-beta.19), Barretenberg/bb (4.0.0-nightly.20260120)

**Build circuit artifacts and generate verifier:**
```bash
cd circuits/scripts
./build.sh
```

**Build contracts:**
```bash
forge build
```

**Run original tests:**
```bash
forge test
nargo test
```

Note: `bb` is missing from the devcontainer (see I-6 in the audit report). Install it manually before running `build.sh`.

</details>
