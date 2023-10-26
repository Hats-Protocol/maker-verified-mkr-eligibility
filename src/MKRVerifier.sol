// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // uncomment before deploy
import { IHatsEligibility } from "hats-protocol/Interfaces/IHatsEligibility.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";

interface ERC20Like {
  function balanceOf(address account) external view returns (uint256);
}

/**
 * @title MKRVerifier
 * @author spengrah
 * @notice This contract is used to verify that a MakerDAO ecosystem actor has a balance of at least the amount of MKR
 * they claim to have.
 * It also serves as an eligibility module for Hats Protocol, and as such be used to determine
 * whether an ecosystem actor is eligible to hold a particular role within the MakerDAO ecosystem.
 */
contract MKRVerifier is IHatsEligibility {
  /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @dev Thrown when an ecosystem actor tries to register more MKR than they have
  error InsufficientMKR();

  /// @dev Thrown when a non-moderator tries to register MKR for an ecosystem actor
  error Unauthorized();

  /// @dev Thrown when a signature is invalid
  error InvalidSignature();

  /*//////////////////////////////////////////////////////////////
                                EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when MKR is registered for an ecosystem actor via this contract
   * @param ecosystemActor The ecosystem actor whose MKR was registered
   * @param amount The amount of MKR that was registered
   * @param message Raw string representation of the recognition submission message required by
   * [MIP113-5.2.1.2.3](https://mips.makerdao.com/mips/details/MIP113#5-2-1-2-3).
   */
  event MKRRegistered(address ecosystemActor, uint256 amount, string message);

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  /// @notice The MKR token contract
  ERC20Like public constant MKR = ERC20Like(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);

  /// @notice The Hats Protocol contract
  IHats public constant HATS = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137); // v1.hatsprotocol.eth

  /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
  //////////////////////////////////////////////////////////////*/

  /// @notice The hat ID of the moderator role
  uint256 public facilitatorHat;

  /// @notice The amount of MKR an ecosystem actor has registered with this contract
  mapping(address ecosystemActor => uint256 registeredAmount) public registeredMKR;

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Create a new MKRVerifier contract
   * @param _facilitatorHat The hat ID of the moderator role
   */
  constructor(uint256 _facilitatorHat) {
    // set the moderator hat
    facilitatorHat = _facilitatorHat;
  }

  /*//////////////////////////////////////////////////////////////
                      HATS ELIGIBILITY FUNCTION
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IHatsEligibility
  function getWearerStatus(address _wearer, uint256 /*_hatId */ )
    public
    view
    virtual
    override
    returns (bool eligible, bool standing)
  {
    /// @dev this module doesn't deal with standing, so we default it to true
    standing = true;

    /**
     * @dev wearers are eligible if they have at least some verified MKR, ie...
     *    1) they have registered some MKR with this contract, and
     *    2) their present MKR balance is greater than or equal to their amount registered
     */
    eligible = getVerifiedMKR(_wearer) > 0;
  }

  /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Register an amount of MKR to be used for eligibility verification. The caller must have at least as much
   * MKR as they are trying to register.
   * This function can also be used by an ecosystem actor to update their registered amount.
   * @param _amount The amount of MKR to register
   * @param _message Raw string representation of the recognition submission message required by
   * [MIP113-5.2.1.2.3](https://mips.makerdao.com/mips/details/MIP113#5-2-1-2-3).
   */
  function registerMKR(uint256 _amount, string calldata _message) public {
    _registerMKR(msg.sender, _amount, _message);
  }

  /*//////////////////////////////////////////////////////////////
                          MODERATOR FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Register an amount of MKR to be used for eligibility verification for an `_ecosystemActor`. The
   * `_ecosystemActor` must have at least as much MKR as the registration `_amount`. Can only be called by a wearer of
   * the moderator hat.
   * @param _ecosystemActor The ecosystem actor to register MKR for.
   * @param _amount The amount of MKR to register. Must be <= the ecosystem actor's MKR balance.
   * @param _message Raw string representation of the recognition submission message required by
   * [MIP113-5.2.1.2.3](https://mips.makerdao.com/mips/details/MIP113#5-2-1-2-3).
   * @param _sig An EIP-191-compatible signature by `_ecosystemActor` of the EIP-191-compatible hash of `_message`.
   * @custom:version Next version should use EIP712 signatures
   */
  function registerMKRFor(address _ecosystemActor, uint256 _amount, string calldata _message, bytes calldata _sig)
    public
  {
    // only the moderator can register MKR for an ecosystem actor
    if (!HATS.isWearerOfHat(msg.sender, facilitatorHat)) revert Unauthorized();

    // verify the signature
    if (!_verifySig(_ecosystemActor, _message, _sig)) revert InvalidSignature();

    // check balance and register the MKR
    _registerMKR(_ecosystemActor, _amount, _message);
  }

  /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Get the amount of verified MKR an ecosystem actor. An ecosystem actor's verified MKR is the amount of MKR
   * they have registered with this contract, as long as their present MKR balance is greater than or equal to that
   * amount. If their balance is lower than their registered amount, their verified amount is 0.
   * @param _ecosystemActor The ecosystem actor to check.
   * @return verifiedAmount The amount of verified MKR the ecosystem actor has.
   */
  function getVerifiedMKR(address _ecosystemActor) public view returns (uint256 verifiedAmount) {
    uint256 registeredAmount = registeredMKR[_ecosystemActor];

    // set verified amount to registered amount if their balance covers the registered amount
    // otherwise, verified amount remains 0 (as initialized)
    if (MKR.balanceOf(_ecosystemActor) >= registeredAmount) verifiedAmount = registeredAmount;
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Check an `ecosystemActor`'s MKR balance and register the MKR if they have enough
   * @param _ecosystemActor The ecosystem actor to register MKR for.
   * @param _amount The amount of MKR to register. Must be <= the ecosystem actor's MKR balance.
   */
  function _registerMKR(address _ecosystemActor, uint256 _amount, string calldata _message) internal {
    // the ecosystem actor must have at least as much MKR as they are trying to register
    if (MKR.balanceOf(_ecosystemActor) < _amount) revert InsufficientMKR();

    // set the ecosystem actor's registered amount
    registeredMKR[_ecosystemActor] = _amount;

    // log the registration
    emit MKRRegistered(_ecosystemActor, _amount, _message);
  }

  /**
   * @dev Verify whether `_sig` is a valid EIP-191 signature of `_message` by `_ecosystemActor`. First converts the
   * `_message` to an EIP-191-compatible message hash, then checks the signature against that hash.
   * @param _ecosystemActor The ecosystem actor who signed the message.
   * @param _message A raw string message.
   * @param _sig An EIP-191-compatible signature by `_ecosystemActor` of the EIP-191-compatible hash of `_message`.
   */
  function _verifySig(address _ecosystemActor, string calldata _message, bytes calldata _sig)
    internal
    view
    returns (bool)
  {
    return SignatureCheckerLib.isValidSignatureNowCalldata(
      _ecosystemActor, SignatureCheckerLib.toEthSignedMessageHash(abi.encode(_message)), _sig
    );
  }
}
