# MKR Verifier

An onchain registry for Verified MKR, which also serves as an Eligibility Module for use with Hats Protocol.

## Overview and Usage

This contract serves as an onchain registry for Verified MKR of Maker Ecosystem Actors. Ecosystem Actors can register their MKR holdings, and this contract can be used to verify in realtime whether they continue to hold at least that much MKR and as the source of truth for the Actor's voting weight in AVC voting. 

Governance Facilitators can register MKR on behalf of Ecosystem Actors who have taken the traditional route of posting their MKR verification to the Maker Governance Forum.

This contract also serves as an Eligibility Module for Hats Protocol hats, with eligibility determined by whether an Ecosystem Actor has verified MKR.

### Registering MKR

To register MKR, an Ecosystem Actor must call the `registerMKR` function with the amount of MKR they wish to register. As long as they have a balance of at least that much MKR, the registration will succeed and an `MKRRegistered` event will be emitted to log the registration. 

Ecosystem Actors can also include a message with their registration, which will also be emitted in the event. This message should be the recognition submission message required by [MIP113-5.2.1.2.3](https://mips.makerdao.com/mips/details/MIP113#5-2-1-2-3).

### Registering MKR for an Ecosystem Actor

Governance Facilitators — i.e. wearer(s) of the `facilitatorHat` — can register MKR on behalf of an Ecosystem Actor by calling the `registerMKRFor` function with the following parameters:

- `_ecosystemActor` — The address of the Ecosystem Actor.
- `_amount` — The amount of MKR they wish to register as per their forum post. 
- `_message` — The Ecosystem Actor's recognition submission message from their forum post.
- `_signature` — The Ecosystem Actor's signature of the `_message`.

The registration will succeed as long as the following conditions hold:

1. The Ecosystem Actor has an MKR balance of at least `_amount`.
2. The `_signature` is a valid EIP-191 / `eth_sign` signature of the `_message` by the Ecosystem Actor.

## Development

This repo uses Foundry for development and testing. To get started:

1. Fork the project
2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
3. To install dependencies, run `forge install`
4. To compile the contracts, run `forge build`
5. To test, run `forge test`