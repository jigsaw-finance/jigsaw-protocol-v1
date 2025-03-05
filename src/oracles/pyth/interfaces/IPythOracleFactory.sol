// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPythOracleFactory
 * @dev Interface for the PythOracleFactory contract.
 */
interface IPythOracleFactory {
    // -- Events --

    /**
     * @notice Emitted when the pyth address is updated.
     * @param pyth Address of the pyth oracle.
     */
    event PythAddressUpdated(address indexed pyth);

    /**
     * @notice Emitted when the reference implementation is updated.
     * @param newImplementation Address of the new reference implementation.
     */
    event PythOracleImplementationUpdated(address indexed newImplementation);

    // -- State variables --

    /**
     * @notice Gets the address of the underlying Pyth oracle used for cloning.
     * @return Address of the underlying Pyth oracle.
     */
    function pyth() external view returns (address);

    /**
     * @notice Gets the address of the reference implementation.
     * @return Address of the reference implementation.
     */
    function referenceImplementation() external view returns (address);

    /**
     * @notice Sets the reference implementation address.
     * @param _referenceImplementation Address of the new reference implementation contract.
     */
    function setPythOracleReferenceImplementation(
        address _referenceImplementation
    ) external;

    /**
     * @notice Creates a new Pyth oracle by cloning the reference implementation.
     *
     * @param _initialOwner The address of the initial owner of the contract.
     * @param _underlying The address of the token the oracle is for.
     * @param _priceId The Pyth's priceId used to determine the price of the `underlying`.
     * @param _age The Age in seconds after which the price is considered invalid.
     *
     * @return newPythOracleAddress Address of the newly created Pyth oracle.
     */
    function createPythOracle(
        address _initialOwner,
        address _underlying,
        bytes32 _priceId,
        uint256 _age
    ) external returns (address newPythOracleAddress);
}
