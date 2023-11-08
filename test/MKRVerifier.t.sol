// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2 } from "forge-std/Test.sol";
import { IHats, MKRVerifier } from "../src/MKRVerifier.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { Deploy } from "../script/Deploy.s.sol";

interface ERC20Like {
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
}

contract MKRVerifierTest is Deploy, Test {
  /// @dev Inherit from DeployPrecompiled instead of Deploy if working with pre-compiled contracts

  /// @dev variables inhereted from Deploy script
  // MKRVerifier public mkrVerifier;
  // bytes32 public SALT;
  // uint256 public facilitatorHat;
  // address public mkr;

  uint256 public fork;
  uint256 public BLOCK_NUMBER = 17_671_864; // deployment block for Hats.sol
  ERC20Like public MKR = ERC20Like(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
  IHats public HATS = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137); // v1.hatsproocol.eth

  error InsufficientMKR();
  error Unauthorized();
  error InvalidSignature();

  event MKRRegistered(address ecosystemActor, uint256 amount, string message);

  address public dao = makeAddr("dao");
  address public facilitator = makeAddr("facilitator");
  address public actor1;
  address public actor2;
  address public nonActor;
  uint256 public actor1Key;
  uint256 public actor2Key;
  uint256 public nonActorKey;

  uint256 public tophat;

  uint256 public amountToRegister;

  string public message = "I am a MakerDAO ecosystem actor";
  bytes public signature;

  function setUp() public virtual {
    // set up accounts
    (actor1, actor1Key) = makeAddrAndKey("actor1");
    (actor2, actor2Key) = makeAddrAndKey("actor2");
    (nonActor, nonActorKey) = makeAddrAndKey("nonActor");

    // create and activate a fork, at BLOCK_NUMBER
    fork = vm.createSelectFork(vm.rpcUrl("mainnet"), BLOCK_NUMBER);

    // set up the hats
    tophat = HATS.mintTopHat(address(this), "tophat", "image/tophat");
    facilitatorHat =
      HATS.createHat(tophat, "facilitator", 1, makeAddr("eligibility"), makeAddr("toggle"), true, "image/facilitator");
    HATS.mintHat(facilitatorHat, facilitator);

    // deploy mkrVerifier via the script
    prepare(false, address(MKR), facilitatorHat);
    run();

    // deal MKR to actor1 and actor2
    deal(address(MKR), actor1, 1000);
    deal(address(MKR), actor2, 2000);
  }
}

contract Deploying is MKRVerifierTest {
  function test_mkr() public {
    assertEq(address(mkrVerifier.MKR()), address(MKR));
  }
}

contract SelfRegistering is MKRVerifierTest {
  function test_register() public {
    amountToRegister = 500;

    vm.expectEmit();
    emit MKRRegistered(actor1, amountToRegister, message);
    vm.prank(actor1);
    mkrVerifier.registerMKR(amountToRegister, message);

    assertEq(mkrVerifier.registeredMKR(actor1), amountToRegister);
  }

  function test_revert_insufficient_mkr() public {
    amountToRegister = 5000;

    assertGt(amountToRegister, MKR.balanceOf(actor1));

    vm.expectRevert(InsufficientMKR.selector);
    vm.prank(actor1);
    mkrVerifier.registerMKR(amountToRegister, message);

    assertEq(mkrVerifier.registeredMKR(actor1), 0);
  }

  function test_register_2actors() public {
    amountToRegister = 500;
    string memory message2 = "I am another MakerDAO ecosystem actor";

    // actor1 registers
    vm.expectEmit();
    emit MKRRegistered(actor1, amountToRegister, message);
    vm.prank(actor1);
    mkrVerifier.registerMKR(amountToRegister, message);

    // actor2 registers with more MKR
    vm.expectEmit();
    emit MKRRegistered(actor2, amountToRegister + 1, message2);
    vm.prank(actor2);
    mkrVerifier.registerMKR(amountToRegister + 1, message2);

    assertEq(mkrVerifier.registeredMKR(actor1), amountToRegister);
    assertEq(mkrVerifier.registeredMKR(actor2), amountToRegister + 1);
  }
}

contract facilitatorRegistering is MKRVerifierTest {
  function signMessage(uint256 _pk, string memory _message) public pure returns (bytes memory signature) {
    bytes32 digest = ECDSA.toEthSignedMessageHash(abi.encodePacked(_message));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, digest);
    signature = abi.encodePacked(r, s, v);
  }

  function test_happy_actor1_facilitator() public {
    amountToRegister = 500;
    signature = signMessage(actor1Key, message);

    vm.expectEmit();
    emit MKRRegistered(actor1, amountToRegister, message);
    vm.prank(facilitator);
    mkrVerifier.registerMKRFor(actor1, amountToRegister, message, signature);

    assertEq(mkrVerifier.registeredMKR(actor1), amountToRegister);
  }

  function test_revert_nonActor_facilitator() public {
    amountToRegister = 500;
    signature = signMessage(nonActorKey, message);

    vm.expectRevert(InsufficientMKR.selector);
    vm.prank(facilitator);
    mkrVerifier.registerMKRFor(nonActor, amountToRegister, message, signature);

    assertEq(mkrVerifier.registeredMKR(nonActor), 0);
  }

  function test_revert_actor_nonfacilitator() public {
    amountToRegister = 500;
    signature = signMessage(actor1Key, message);

    vm.expectRevert(Unauthorized.selector);
    vm.prank(nonActor);
    mkrVerifier.registerMKRFor(actor1, amountToRegister, message, signature);

    assertEq(mkrVerifier.registeredMKR(actor1), 0);
  }

  function test_revert_invalidSig_actor_facilitator() public {
    amountToRegister = 500;
    signature = abi.encode("this is not a signature");

    vm.expectRevert(InvalidSignature.selector);
    vm.prank(facilitator);
    mkrVerifier.registerMKRFor(actor1, amountToRegister, message, signature);

    assertEq(mkrVerifier.registeredMKR(actor1), 0);
  }

  function test_revert_insufficientMKR_actor_facilitator() public {
    amountToRegister = 5000;
    signature = signMessage(nonActorKey, message);

    vm.expectRevert(InsufficientMKR.selector);
    vm.prank(facilitator);
    mkrVerifier.registerMKRFor(nonActor, amountToRegister, message, signature);

    assertEq(mkrVerifier.registeredMKR(nonActor), 0);
  }
}

contract Verifying_And_GetWearerStatus is MKRVerifierTest {
  bool public eligible;

  function setUp() public override {
    super.setUp();
  }

  function test_true_registered_more() public {
    amountToRegister = 500;
    // registers less than the amount they have
    assertLt(amountToRegister, MKR.balanceOf(actor1));
    vm.prank(actor1);
    mkrVerifier.registerMKR(amountToRegister, message);

    assertEq(mkrVerifier.getVerifiedMKR(actor1), amountToRegister);
    (eligible,) = mkrVerifier.getWearerStatus(actor1, 0);
    assertEq(eligible, true);
  }

  function test_true_registered_same() public {
    amountToRegister = 1000;
    // registers exactly the amount they have
    assertEq(amountToRegister, MKR.balanceOf(actor1));
    vm.prank(actor1);
    mkrVerifier.registerMKR(amountToRegister, message);

    assertEq(mkrVerifier.getVerifiedMKR(actor1), amountToRegister);
    (eligible,) = mkrVerifier.getWearerStatus(actor1, 0);
    assertEq(eligible, true);
  }

  function test_false_registered_less() public {
    amountToRegister = 1000;
    // registers exactly the amount they have
    assertEq(amountToRegister, MKR.balanceOf(actor1));
    vm.prank(actor1);
    mkrVerifier.registerMKR(amountToRegister, message);
    assertEq(mkrVerifier.getVerifiedMKR(actor1), amountToRegister);

    // actor1 transfers some MKR
    vm.prank(actor1);
    MKR.transfer(actor2, 500);

    assertEq(mkrVerifier.getVerifiedMKR(actor1), 0);
    (eligible,) = mkrVerifier.getWearerStatus(actor1, 0);
    assertEq(eligible, false);
  }

  function test_false_unregistered() public {
    // does not register anything

    assertEq(mkrVerifier.getVerifiedMKR(actor1), 0);
    (eligible,) = mkrVerifier.getWearerStatus(actor1, 0);
    assertEq(eligible, false);
  }
}
