// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IOracle } from "../../../interfaces/oracle/IOracle.sol";

interface IChronicleOracle is IOracle {
    // -- Events --

    /**
     * @notice Emitted when a new Chronicle Oracle is created.
     *
     * @dev Tracks the underlying asset, its associated price ID, and the oracle's age.
     *
     * @param underlying The address of the underlying asset for which the oracle is created.
     * @param chronicle The address of the Chronicle Oracle.
     * @param ageValidityPeriod Age in seconds after which the price is considered invalid.
     */
    event ChronicleOracleCreated(address indexed underlying, address indexed chronicle, uint256 ageValidityPeriod);

    /**
     * @notice Emitted when the age for the price is updated.
     *
     * @dev Provides details about the previous and updated age values.
     *
     * @param oldValue The previous age value of the oracle.
     * @param newValue The updated age value of the oracle.
     */
    event AgeValidityPeriodUpdated(uint256 oldValue, uint256 newValue);

    // -- Errors --

    /**
     * @notice Thrown when Chronicle oracle returns a zero price.
     * @dev Zero prices are not valid for the standard token price feeds.
     */
    error ZeroPrice();

    /**
     * @notice Thrown when an invalid age value is provided.
     * @dev This error is used to signal that the age value does not meet the required constraints.
     */
    error InvalidAgeValidityPeriod();

    /**
     * @notice Thrown when the price is outdated.
     * @dev This error is used to signal that the price is outdated.
     * @param minAllowedAge The minimum allowed age of the price based on the current timestamp.
     * @param actualAge The actual age of the price.
     */
    error OutdatedPrice(uint256 minAllowedAge, uint256 actualAge);

    // -- State variables --

    /**
     * @notice Returns the Chronicle Oracle address.
     * @return The address of the Chronicle Oracle.
     */
    function chronicle() external view returns (address);

    /**
     * @notice Returns the allowed age of the returned price in seconds.
     * @return The allowed age in seconds as a uint256 value.
     */
    function ageValidityPeriod() external view returns (uint256);

    // -- Initialization --

    /**
     * @notice Initializes the Oracle contract with necessary parameters.
     *
     * @param _initialOwner The address of the initial owner of the contract.
     * @param _underlying The address of the token the oracle is for.
     * @param _chronicle The Address of the Chronicle Oracle.
     * @param _ageValidityPeriod The Age in seconds after which the price is considered invalid.
     */
    function initialize(
        address _initialOwner,
        address _underlying,
        address _chronicle,
        uint256 _ageValidityPeriod
    ) external;

    // -- Administration --

    /**
     * @notice Updates the age validity period to a new value.
     * @dev Only the contract owner can call this function.
     * @param _newAgeValidityPeriod The new age validity period to be set.
     */
    function updateAgeValidityPeriod(
        uint256 _newAgeValidityPeriod
    ) external;
}
