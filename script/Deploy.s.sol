// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { MKRVerifier } from "../src/MKRVerifier.sol";

contract Deploy is Script {
  MKRVerifier public mkrVerifier;
  bytes32 public SALT = bytes32(abi.encode(0x4a75));
  address public mkr = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2; // mainnet MKR
  uint256 public facilitatorHat =
    323_519_771_394_501_307_089_259_385_432_256_433_664_376_508_480_981_965_228_332_365_643_776; // mainnet 12.1.2.1

  // default values
  bool internal _verbose = true;

  /// @dev Override default values, if desired
  function prepare(bool verbose, address _mkr, uint256 _facilitatorHat) public {
    mkr = _mkr;
    _verbose = verbose;
    facilitatorHat = _facilitatorHat;
  }

  /// @dev Set up the deployer via their private key from the environment
  function deployer() public returns (address) {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    return vm.rememberKey(privKey);
  }

  function _log(string memory prefix) internal view {
    if (_verbose) {
      console2.log(string.concat(prefix, "Module:"), address(mkrVerifier));
    }
  }

  /// @dev Deploy the contract to a deterministic address via forge's create2 deployer factory.
  function run() public virtual {
    vm.startBroadcast(deployer());

    /**
     * @dev Deploy the contract to a deterministic address via forge's create2 deployer factory, which is at this
     * address on all chains: `0x4e59b44847b379578588920cA78FbF26c0B4956C`.
     * The resulting deployment address is determined by only two factors:
     *    1. The bytecode hash of the contract to deploy. Setting `bytecode_hash` to "none" in foundry.toml ensures that
     *       never differs regardless of where its being compiled
     *    2. The provided salt, `SALT`
     */
    mkrVerifier = new MKRVerifier{ salt: SALT}(mkr, facilitatorHat);

    vm.stopBroadcast();

    _log("");
  }
}

/* FORGE CLI COMMANDS

## A. Simulate the deployment locally
forge script script/Deploy.s.sol -f mainnet

## B. Deploy to real network and verify on etherscan
forge script script/Deploy.s.sol -f mainnet --broadcast --verify

## C. Fix verification issues (replace values in curly braces with the actual values)
forge verify-contract --chain-id 1 --num-of-optimizations 1000000 --watch  \
--constructor-args $(cast abi-encode "constructor(address,uint256)" "0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2" 323519771394501307089259385432256433664376508480981965228332365643776 ) \
 --compiler-version v0.8.21 0x357aafef834e9078203a96e9afb188b5f16fb412 \
 src/MKRVerifier.sol:MKRVerifier --etherscan-api-key $ETHERSCAN_KEY

## D. To verify ir-optimized contracts on etherscan...
  1. Run (C) with the following additional flag: `--show-standard-json-input > etherscan.json`
  2. Patch `etherscan.json`: `"optimizer":{"enabled":true,"runs":100}` =>
`"optimizer":{"enabled":true,"runs":100},"viaIR":true`
  3. Upload the patched `etherscan.json` to etherscan manually

  See this github issue for more: https://github.com/foundry-rs/foundry/issues/3507#issuecomment-1465382107
*/
