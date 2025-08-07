// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IChainlinkOracleFactory
 * @dev Interface for the ChainlinkOracleFactory contract.
 */
interface IChainlinkOracleFactory {
    // -- Events --

    /**
     * @notice Emitted when the reference implementation is updated.
     * @param newImplementation Address of the new reference implementation.
     */
    event ChainlinkOracleImplementationUpdated(address indexed newImplementation);

    // -- State variables --

    /**
     * @notice Gets the address of the reference implementation.
     * @return Address of the reference implementation.
     */
    function referenceImplementation() external view returns (address);

    // -- Administration --

    /**
     * @notice Sets the reference implementation address.
     * @param _referenceImplementation Address of the new reference implementation contract.
     */
    function setReferenceImplementation(
        address _referenceImplementation
    ) external;

    // -- Chainlink oracle creation --

    /**
     * @notice Creates a new Chainlink oracle by cloning the reference implementation.
     *
     * @param _initialOwner The address of the initial owner of the contract.
     * @param _underlying The address of the token the oracle is for.
     * @param _chainlinkOracle The Address of the Chainlink Oracle.
     * @param _ageValidityPeriod The Age in seconds after which the price is considered invalid.
     *
     * @return newChainlinkOracleAddress Address of the newly created Chainlink oracle.
     */
    function createChainlinkOracle(
        address _initialOwner,
        address _underlying,
        address _chainlinkOracle,
        uint256 _ageValidityPeriod
    ) external returns (address newChainlinkOracleAddress);
}
