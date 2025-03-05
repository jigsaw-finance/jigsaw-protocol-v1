// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { IReceiptToken } from "./interfaces/core/IReceiptToken.sol";
import { IReceiptTokenFactory } from "./interfaces/core/IReceiptTokenFactory.sol";

/**
 * @title ReceiptTokenFactory
 * @dev This contract is used to create new instances of receipt tokens for strategies using the clone factory pattern.
 */
contract ReceiptTokenFactory is IReceiptTokenFactory, Ownable2Step {
    /**
     * @notice Address of the reference implementation of the receipt token contract.
     */
    address public referenceImplementation;

    // -- Constructor --

    /**
     * @notice Creates a new ReceiptTokenFactory contract.
     * @param _initialOwner The initial owner of the contract.
     * @notice Sets the reference implementation address for the receipt token.
     */
    constructor(address _initialOwner, address _referenceImplementation) Ownable(_initialOwner) {
        // Assert that referenceImplementation has code in it to protect the system from cloning invalid implementation.
        require(_referenceImplementation.code.length > 0, "3096");

        emit ReceiptTokenImplementationUpdated(_referenceImplementation);
        referenceImplementation = _referenceImplementation;
    }

    // -- Administration --

    /**
     * @notice Sets the reference implementation address for the receipt token.
     * @param _referenceImplementation Address of the new reference implementation contract.
     */
    function setReceiptTokenReferenceImplementation(
        address _referenceImplementation
    ) external override onlyOwner {
        // Assert that referenceImplementation has code in it to protect the system from cloning invalid implementation.
        require(_referenceImplementation.code.length > 0, "3096");
        require(_referenceImplementation != referenceImplementation, "3062");

        emit ReceiptTokenImplementationUpdated(_referenceImplementation);
        referenceImplementation = _referenceImplementation;
    }

    // -- Receipt token creation --

    /**
     * @notice Creates a new receipt token by cloning the reference implementation.
     *
     * @param _name Name of the new receipt token.
     * @param _symbol Symbol of the new receipt token.
     * @param _minter Address of the account that will have the minting rights.
     * @param _owner Address of the owner of the new receipt token.
     *
     * @return newReceiptTokenAddress Address of the newly created receipt token.
     */
    function createReceiptToken(
        string memory _name,
        string memory _symbol,
        address _minter,
        address _owner
    ) external override returns (address newReceiptTokenAddress) {
        // Clone the Receipt Token implementation for the new receipt token.
        newReceiptTokenAddress = Clones.cloneDeterministic({
            implementation: referenceImplementation,
            salt: bytes32(uint256(uint160(msg.sender)))
        });

        // Emit the event indicating the successful Receipt Token creation.
        emit ReceiptTokenCreated({
            newReceiptTokenAddress: newReceiptTokenAddress,
            creator: msg.sender,
            name: _name,
            symbol: _symbol
        });

        // Initialize the new receipt token's contract.
        IReceiptToken(newReceiptTokenAddress).initialize({
            __name: _name,
            __symbol: _symbol,
            __minter: _minter,
            __owner: _owner
        });
    }

    /**
     * @dev Renounce ownership override to avoid losing contract's ownership.
     */
    function renounceOwnership() public pure virtual override {
        revert("1000");
    }
}
