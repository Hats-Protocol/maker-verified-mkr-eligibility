// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import { IHatsEligibility } from "hats-protocol/Interfaces/IHatsEligibility.sol";

interface IERC20 {
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

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  IERC20 public constant MKR = IERC20(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);

  /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
  //////////////////////////////////////////////////////////////*/

  /// @notice The amount of MKR an ecosystem actor has registered with this contract
  mapping(address ecosystemActor => uint256 registeredAmount) public registeredMKR;

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
     *    2) their present MKR balance is greater than or equal to their registered amount
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
   */
  function registerMKR(uint256 _amount) public {
    // get the caller's current MKR balance
    uint256 balance = MKR.balanceOf(msg.sender);

    // the caller must have at least as much MKR as they are trying to register
    if (balance < _amount) revert InsufficientMKR();

    // set the caller's registered amount
    registeredMKR[msg.sender] = _amount;
  }

  /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Get the amount of verified MKR an ecosystem actor. An ecosystem actor's verified MKR is the amount of MRK
   * they have registered with this contract, as long as their present MKR balance is greater than or equal to that
   * amount. If their balance is lower than their registered amount, their verified amount is 0.
   * @param _ecosystemActor The ecosystem actor to check
   * @return verifiedAmount The amount of verified MKR the ecosystem actor has
   */
  function getVerifiedMKR(address _ecosystemActor) public view returns (uint256 verifiedAmount) {
    uint256 registeredAmount = registeredMKR[_ecosystemActor];

    // set verified amount to registered amount if their balance covers the registered amount
    // otherwise, verified amount remains 0 (as initialized)
    if (MKR.balanceOf(_ecosystemActor) >= registeredAmount) verifiedAmount = registeredAmount;
  }
}
