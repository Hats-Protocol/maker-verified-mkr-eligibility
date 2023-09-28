// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2 } from "forge-std/Test.sol";
import { MKRVerifier } from "../src/MKRVerifier.sol";
import { Deploy, DeployPrecompiled } from "../script/Deploy.s.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";

contract MKRVerifierTest is Deploy, Test {
  /// @dev Inherit from DeployPrecompiled instead of Deploy if working with pre-compiled contracts

  /// @dev variables inhereted from Deploy script
  // MKRVerifier public mkrVerifier;
  // bytes32 public SALT;

  uint256 public fork;
  uint256 public BLOCK_NUMBER = 17_671_864; // deployment block for Hats.sol
  IHats public HATS = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137); // v1.hatsprotocol.eth

  string public MODULE_VERSION;

  function setUp() public virtual {
    // create and activate a fork, at BLOCK_NUMBER
    fork = vm.createSelectFork(vm.rpcUrl("mainnet"), BLOCK_NUMBER);

    // deploy mkrVerifier via the script
    prepare(false, MODULE_VERSION);
    run();
  }
}


contract UnitTests is MKRVerifierTest { }
