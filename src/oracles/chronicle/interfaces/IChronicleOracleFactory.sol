// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IChronicleOracleFactory
 * @dev Interface for the ChronicleOracleFactory contract.
 */
interface IChronicleOracleFactory {
    // -- Events --

    /**
     * @notice Emitted when the reference implementation is updated.
     * @param newImplementation Address of the new reference implementation.
     */
    event ChronicleOracleImplementationUpdated(address indexed newImplementation);

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

    // -- Chronicle oracle creation --

    /**
     * @notice Creates a new Chronicle oracle by cloning the reference implementation.
     *
     * @param _initialOwner The address of the initial owner of the contract.
     * @param _underlying The address of the token the oracle is for.
     * @param _chronicle The Address of the Chronicle Oracle.
     * @param _ageValidityPeriod The Age in seconds after which the price is considered invalid.
     *
     * @return newChronicleOracleAddress Address of the newly created Chronicle oracle.
     */
    function createChronicleOracle(
        address _initialOwner,
        address _underlying,
        address _chronicle,
        uint256 _ageValidityPeriod
    ) external returns (address newChronicleOracleAddress);
}
