// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {TreasureHunt} from "../src/TreasureHunt.sol";
import {HonkVerifier} from "../src/Verifier.sol";

/// @notice Fuzz tests covering recipient validation, fund amounts, emergency
///         withdraw bounds, and claim-count integrity.
contract TreasureHuntFuzzTest is Test {
    HonkVerifier verifier;
    TreasureHunt hunt;

    address constant OWNER = address(0xDEADBEEF);
    address constant PARTICIPANT = address(0xBEEF);
    uint256 constant INITIAL_FUNDING = 100 ether;

    function setUp() public {
        vm.deal(OWNER, 200 ether);
        vm.deal(PARTICIPANT, 50 ether);
        vm.startPrank(OWNER);
        verifier = new HonkVerifier();
        hunt = new TreasureHunt{value: INITIAL_FUNDING}(address(verifier));
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Recipient validation
    // -------------------------------------------------------------------------

    /// @dev Any address that passes all recipient checks should receive exactly
    ///      REWARD wei after a successful claim (stub verifier always passes).
    function testFuzz_ValidRecipientReceivesReward(address recipient) public {
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(hunt));
        vm.assume(recipient != OWNER);
        vm.assume(recipient != address(this)); // msg.sender in this test
        vm.assume(uint160(recipient) > 10);    // skip precompiles
        vm.assume(recipient.code.length == 0); // must be EOA to receive ETH

        uint256 before = recipient.balance;
        hunt.claim(bytes(""), keccak256("treasure"), payable(recipient));
        assertEq(recipient.balance, before + hunt.REWARD());
    }

    /// @dev Zero address must always revert regardless of proof / hash content.
    function testFuzz_ZeroRecipientAlwaysReverts(bytes calldata proof, bytes32 hash) public {
        vm.expectRevert(TreasureHunt.InvalidRecipient.selector);
        hunt.claim(proof, hash, payable(address(0)));
    }

    /// @dev Contract address as recipient must always revert.
    function testFuzz_ContractSelfRecipientAlwaysReverts(bytes calldata proof, bytes32 hash) public {
        vm.expectRevert(TreasureHunt.InvalidRecipient.selector);
        hunt.claim(proof, hash, payable(address(hunt)));
    }

    /// @dev Owner as recipient must always revert.
    function testFuzz_OwnerRecipientAlwaysReverts(bytes calldata proof, bytes32 hash) public {
        vm.expectRevert(TreasureHunt.InvalidRecipient.selector);
        hunt.claim(proof, hash, payable(OWNER));
    }

    /// @dev msg.sender as recipient must always revert.
    function testFuzz_CallerAsRecipientAlwaysReverts(bytes calldata proof, bytes32 hash) public {
        // address(this) is msg.sender from this test contract's perspective
        vm.expectRevert(TreasureHunt.InvalidRecipient.selector);
        hunt.claim(proof, hash, payable(address(this)));
    }

    // -------------------------------------------------------------------------
    // Fund
    // -------------------------------------------------------------------------

    /// @dev Owner can fund any positive amount; balance must increase exactly.
    function testFuzz_OwnerFundIncreasesBalance(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(OWNER, uint256(amount));
        uint256 before = hunt.getContractBalance();
        vm.prank(OWNER);
        hunt.fund{value: amount}();
        assertEq(hunt.getContractBalance(), before + uint256(amount));
    }

    /// @dev Any non-owner is always rejected when funding.
    function testFuzz_NonOwnerFundAlwaysReverts(address caller, uint96 amount) public {
        vm.assume(caller != OWNER);
        vm.assume(amount > 0);
        vm.deal(caller, uint256(amount));
        vm.prank(caller);
        vm.expectRevert("ONLY_OWNER_CAN_FUND");
        hunt.fund{value: amount}();
    }

    // -------------------------------------------------------------------------
    // Emergency withdraw
    // -------------------------------------------------------------------------

    /// @dev Owner can emergency-withdraw any amount within [1, balance].
    function testFuzz_EmergencyWithdrawValidAmount(uint256 amount) public {
        amount = bound(amount, 1, address(hunt).balance);
        vm.prank(OWNER);
        hunt.pause();

        uint256 before = PARTICIPANT.balance;
        vm.prank(OWNER);
        hunt.emergencyWithdraw(payable(PARTICIPANT), amount);

        assertEq(PARTICIPANT.balance, before + amount);
        assertEq(hunt.getContractBalance(), INITIAL_FUNDING - amount);
    }

    /// @dev Amount exceeding balance must always revert.
    function testFuzz_EmergencyWithdrawAboveBalanceReverts(uint256 excess) public {
        excess = bound(excess, 1, type(uint128).max);
        vm.prank(OWNER);
        hunt.pause();
        vm.prank(OWNER);
        vm.expectRevert("INVALID_AMOUNT");
        hunt.emergencyWithdraw(payable(PARTICIPANT), address(hunt).balance + excess);
    }

    /// @dev Any non-owner emergency withdraw must always revert.
    function testFuzz_NonOwnerEmergencyWithdrawReverts(address caller) public {
        vm.assume(caller != OWNER);
        vm.prank(OWNER);
        hunt.pause();
        vm.prank(caller);
        vm.expectRevert("ONLY_OWNER_CAN_EMERGENCY_WITHDRAW");
        hunt.emergencyWithdraw(payable(PARTICIPANT), 1 ether);
    }

    // -------------------------------------------------------------------------
    // Claims count
    // -------------------------------------------------------------------------

    /// @dev Every successful claim increments claimsCount by exactly 1.
    function testFuzz_EachClaimIncrementsCountByOne(bytes32 hash) public {
        // bytes32(0) coincides with the uninitialized _treasureHash slot;
        // skip it to avoid an accidental correct-revert on second claim.
        vm.assume(hash != bytes32(0));
        address payable recipient = payable(makeAddr("recipient"));
        uint256 before = hunt.claimsCount();
        hunt.claim(bytes(""), hash, recipient);
        assertEq(hunt.claimsCount(), before + 1);
    }

    /// @dev claimsCount must never exceed MAX_TREASURES for any sequence of hashes.
    function testFuzz_ClaimsCountNeverExceedsMax(bytes32[10] calldata hashes) public {
        // Fund extra ETH so NotEnoughFunds doesn't fire before AllTreasuresClaimed.
        // (The contract checks balance < REWARD before claimsCount >= MAX_TREASURES.)
        vm.prank(OWNER);
        hunt.fund{value: 100 ether}();

        address payable recipient = payable(makeAddr("recipient"));
        for (uint256 i = 0; i < 10; i++) {
            // Remap bytes32(0) so it doesn't accidentally trigger the zero-slot guard.
            bytes32 h = hashes[i] == bytes32(0) ? bytes32(uint256(i + 1)) : hashes[i];
            hunt.claim(bytes(""), h, recipient);
        }
        assertEq(hunt.claimsCount(), hunt.MAX_TREASURES());

        vm.expectRevert(TreasureHunt.AllTreasuresClaimed.selector);
        hunt.claim(bytes(""), keccak256("extra"), payable(makeAddr("extra")));
    }
}
