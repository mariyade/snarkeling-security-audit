// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {TreasureHunt} from "../src/TreasureHunt.sol";
import {HonkVerifier} from "../src/Verifier.sol";
import {TreasureHuntHandler} from "./handlers/TreasureHuntHandler.sol";

/// @notice Invariant (stateful fuzz) test suite.
///
///         Foundry calls handler functions in random sequences with random
///         inputs, then asserts each invariant after every call.
///
///         Three invariants are safety properties (must never break).
///         One invariant is intentionally expected to FAIL — it exposes H-2
///         (double-spend) by showing that more claims were processed than
///         unique treasure hashes, which is only possible through replay.
contract TreasureHuntInvariants is Test {
    HonkVerifier verifier;
    TreasureHunt hunt;
    TreasureHuntHandler handler;

    address constant OWNER = address(0xDEADBEEF);
    uint256 constant INITIAL_FUNDING = 100 ether;

    function setUp() public {
        vm.deal(OWNER, 200 ether);
        vm.startPrank(OWNER);
        verifier = new HonkVerifier();
        hunt = new TreasureHunt{value: INITIAL_FUNDING}(address(verifier));
        vm.stopPrank();

        handler = new TreasureHuntHandler(hunt, OWNER);

        // Only fuzz state-changing handler functions.
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = handler.claim.selector;
        selectors[1] = handler.fund.selector;
        selectors[2] = handler.pause.selector;
        selectors[3] = handler.unpause.selector;
        selectors[4] = handler.emergencyWithdraw.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    // -------------------------------------------------------------------------
    // Safety invariants — must never break
    // -------------------------------------------------------------------------

    /// @dev claimsCount is bounded by MAX_TREASURES at all times.
    function invariant_claimsCountNeverExceedsMax() public view {
        assertLe(hunt.claimsCount(), hunt.MAX_TREASURES());
    }

    /// @dev The owner address is immutable and must never change.
    function invariant_ownerNeverChanges() public view {
        assertEq(hunt.getOwner(), OWNER);
    }

    /// @dev The verifier address must never become address(0).
    ///      (Handler does not call updateVerifier, so this should hold.)
    function invariant_verifierNeverZero() public view {
        assertNotEq(hunt.getVerifier(), address(0));
    }

    /// @dev Ghost variable ghost_totalClaimed must track claimsCount exactly —
    ///      every successful claim increments both by one.
    function invariant_ghostTotalClaimedMatchesContract() public view {
        assertEq(hunt.claimsCount(), handler.ghost_totalClaimed());
    }

    // -------------------------------------------------------------------------
    // Bug-exposing invariant — EXPECTED TO FAIL, proving H-2
    // -------------------------------------------------------------------------
    //
    // In a correctly implemented contract:
    //   total successful claims == number of unique treasure hashes claimed
    //
    // Because claim() should revert on a duplicate hash, each slot can only
    // be filled once. Therefore claimsCount would equal ghost_uniqueHashesClaimed.
    //
    // H-2 breaks this: claimed[_treasureHash] reads bytes32(0) (the never-
    // assigned immutable), so the duplicate guard never fires for any non-zero
    // hash. Foundry will find a sequence where the same hash is claimed twice,
    // producing:
    //   hunt.claimsCount()            = 2
    //   handler.ghost_uniqueHashesClaimed = 1
    // and report the counterexample.
    //
    // Run: forge test --match-test invariant_doubleSpendProtection -vvvv
    //
    /// @dev ⚠️  EXPECTED TO FAIL — counterexample proves H-2 (double-spend).
    function invariant_doubleSpendProtection_FAILS_PROVING_H2() public view {
        assertEq(hunt.claimsCount(), handler.ghost_uniqueHashesClaimed());
    }
}
