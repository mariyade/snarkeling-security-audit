// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {TreasureHunt} from "../../src/TreasureHunt.sol";

/// @notice Foundry invariant handler. Wraps all state-changing functions so
///         the fuzzer can call them in arbitrary sequences, while ghost
///         variables track expected state for invariant assertions.
contract TreasureHuntHandler is Test {
    TreasureHunt public hunt;
    address public owner;

    // --- Ghost variables ---
    // Tracks every successful claim call, including replays of the same hash.
    uint256 public ghost_totalClaimed;
    // Tracks how many *unique* hashes have ever successfully claimed.
    // In a correct implementation this would equal claimsCount.
    // Due to H-2 the same hash can claim multiple times, so
    // ghost_totalClaimed > ghost_uniqueHashesClaimed becomes possible.
    uint256 public ghost_uniqueHashesClaimed;

    uint256 public ghost_totalFunded;
    uint256 public ghost_totalEmergencyWithdrawn;

    mapping(bytes32 => bool) internal _seenHash;

    // Small fixed set of hashes — makes the fuzzer find hash collisions (H-2) quickly.
    bytes32[4] internal _hashes = [
        keccak256("treasure1"),
        keccak256("treasure2"),
        keccak256("treasure3"),
        keccak256("treasure4")
    ];

    address[] internal _actors;

    constructor(TreasureHunt _hunt, address _owner) {
        hunt = _hunt;
        owner = _owner;
        for (uint256 i = 0; i < 5; i++) {
            address actor = makeAddr(string(abi.encodePacked("actor", i)));
            _actors.push(actor);
            vm.deal(actor, 100 ether);
        }
    }

    // --- Handlers ---

    function claim(uint256 actorSeed, uint256 hashSeed) external {
        if (hunt.claimsCount() >= hunt.MAX_TREASURES()) return;
        if (hunt.isPaused()) return;
        if (address(hunt).balance < hunt.REWARD()) return;

        address actor = _actors[actorSeed % _actors.length];
        bytes32 treasureHash = _hashes[hashSeed % _hashes.length];
        address payable recipient = payable(makeAddr(string(abi.encodePacked("recipient", actorSeed, hashSeed))));

        vm.prank(actor);
        try hunt.claim(bytes(""), treasureHash, recipient) {
            ghost_totalClaimed++;
            if (!_seenHash[treasureHash]) {
                _seenHash[treasureHash] = true;
                ghost_uniqueHashesClaimed++;
            }
        } catch {}
    }

    function fund(uint256 amount) external {
        amount = bound(amount, 0.01 ether, 50 ether);
        vm.deal(owner, amount);
        vm.prank(owner);
        try hunt.fund{value: amount}() {
            ghost_totalFunded += amount;
        } catch {}
    }

    function pause() external {
        if (hunt.isPaused()) return;
        vm.prank(owner);
        hunt.pause();
    }

    function unpause() external {
        if (!hunt.isPaused()) return;
        vm.prank(owner);
        hunt.unpause();
    }

    function emergencyWithdraw(uint256 amount) external {
        if (!hunt.isPaused()) return;
        if (address(hunt).balance == 0) return;
        amount = bound(amount, 1, address(hunt).balance);
        address payable recipient = payable(makeAddr("emergencyRecipient"));
        vm.prank(owner);
        try hunt.emergencyWithdraw(recipient, amount) {
            ghost_totalEmergencyWithdrawn += amount;
        } catch {}
    }
}
