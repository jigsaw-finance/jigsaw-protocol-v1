// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IReceiptTokenFactory {
    /**
     * @notice Emitted when ReceiptToken reference implementation is updated.
     * @param newReceiptTokenImplementationAddress Address of the new Receipt Token implementation.
     */
    event ReceiptTokenImplementationUpdated(address indexed newReceiptTokenImplementationAddress);

    /**
     * @notice Emitted when a new receipt token is created.
     *
     * @param newReceiptTokenAddress Address of the newly created receipt token.
     * @param creator Address of the account that initiated the creation.
     * @param name Name of the new receipt token.
     * @param symbol Symbol of the new receipt token.
     */
    event ReceiptTokenCreated(
        address indexed newReceiptTokenAddress, address indexed creator, string name, string symbol
    );

    /**
     * @notice Sets the reference implementation address for the receipt token.
     * @param _referenceImplementation Address of the new reference implementation contract.
     */
    function setReceiptTokenReferenceImplementation(
        address _referenceImplementation
    ) external;

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
    ) external returns (address);
}
