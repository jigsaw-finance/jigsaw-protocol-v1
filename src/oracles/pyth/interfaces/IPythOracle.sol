// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IOracle } from "../../../interfaces/oracle/IOracle.sol";

interface IPythOracle is IOracle {
    // -- Events --

    /**
     * @notice Emitted when a new Pyth Oracle is created.
     *
     * @dev Tracks the underlying asset, its associated price ID, and the oracle's age.
     * @dev Please consult  See https://www.pyth.network/developers/price-feed-ids#pyth-evm-stable to get the priceId.
     *
     * @param underlying The address of the underlying asset for which the oracle is created.
     * @param priceId The unique price ID associated with the underlying.
     * @param age Age in seconds after which the price is considered invalid.
     */
    event PythOracleCreated(address indexed underlying, bytes32 indexed priceId, uint256 age);

    /**
     * @notice Emitted when the age for the price is updated.
     *
     * @dev Provides details about the previous and updated age values.
     *
     * @param oldValue The previous age value of the oracle.
     * @param newValue The updated age value of the oracle.
     */
    event AgeUpdated(uint256 oldValue, uint256 newValue);

    /**
     * @notice Emitted when the confidence percentage for the price is updated.
     *
     * @dev Provides details about the previous and updated confidence percentage values.
     *
     * @param oldValue The previous confidence percentage value of the oracle.
     * @param newValue The updated confidence percentage value of the oracle.
     */
    event ConfidencePercentageUpdated(uint256 oldValue, uint256 newValue);

    // -- Errors --

    /**
     * @notice Thrown when Pyth oracle returns an invalid price.
     * @dev Invalid prices are not valid for the standard token price feeds.
     */
    error InvalidOraclePrice();

    /**
     * @notice Thrown when Pyth price exponent is positive
     * @dev Positive exponents would make the price too large after normalization
     */
    error ExpoTooBig();

    /**
     * @notice Thrown when Pyth price exponent is too small (absolute value too large)
     * @dev The exponent's absolute value must not exceed ALLOWED_DECIMALS to prevent underflow
     * @dev Example: If ALLOWED_DECIMALS = 18 and expo = -19, this error will be thrown
     */
    error ExpoTooSmall();

    /**
     * @notice Thrown when an invalid age value is provided.
     * @dev This error is used to signal that the age value does not meet the required constraints (must be > 0).
     */
    error InvalidAge();

    /**
     * @notice Thrown when an invalid confidence percentage value is provided.
     * @dev This error is used to signal that the confidence percentage value does not meet the required constraints
     * @dev Must be > 0 and <= `CONFIDENCE_PRECISION`.
     */
    error InvalidConfidencePercentage();

    /**
     * @notice Thrown when an invalid confidence value is provided.
     * @dev This error is used to signal that the confidence is greater than the price, which would lead to underflow.
     */
    error InvalidConfidence();

    // -- State variables --

    /**
     * @notice Returns the Pyth Oracle address.
     * @return The address of the Pyth Oracle.
     */
    function pyth() external view returns (address);

    /**
     * @notice Returns the Pyth's priceId used to determine the price of the `underlying`.
     * @return The priceId as a bytes32 value.
     */
    function priceId() external view returns (bytes32);

    /**
     * @notice Returns the allowed age of the returned price in seconds.
     * @return The allowed age in seconds as a uint256 value.
     */
    function age() external view returns (uint256);

    /**
     * @notice The standard decimal precision (18) used for price normalization across the protocol.
     */
    function ALLOWED_DECIMALS() external view returns (uint256);

    /**
     * @notice The minimum confidence percentage.
     * @dev Uses 2 decimal precision, where 1% is represented as 100.
     */
    function minConfidencePercentage() external view returns (uint256);

    /**
     * @notice The precision to be used for the confidence percentage to avoid precision loss.
     */
    function CONFIDENCE_PRECISION() external view returns (uint256);

    // -- Initialization --

    /**
     * @notice Initializes the Oracle contract with necessary parameters.
     *
     * @param _initialOwner The address of the initial owner of the contract.
     * @param _underlying The address of the token the oracle is for.
     * @param _pyth The Address of the Pyth Oracle.
     * @param _priceId The Pyth's priceId used to determine the price of the `underlying`.
     * @param _age The Age in seconds after which the price is considered invalid.
     */
    function initialize(
        address _initialOwner,
        address _underlying,
        address _pyth,
        bytes32 _priceId,
        uint256 _age
    ) external;

    // -- Administration --

    /**
     * @notice Updates the age to a new value.
     * @dev Only the contract owner can call this function.
     * @param _newAge The new age to be set.
     */
    function updateAge(
        uint256 _newAge
    ) external;

    /**
     * @notice Updates the confidence percentage to a new value.
     * @dev Only the contract owner can call this function.
     * @param _newConfidence The new confidence percentage to be set.
     */
    function updateConfidencePercentage(
        uint256 _newConfidence
    ) external;
}
