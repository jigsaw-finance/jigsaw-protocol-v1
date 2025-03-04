// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IPyth } from "@pyth/IPyth.sol";
import { PythStructs } from "@pyth/PythStructs.sol";

import { IPythOracle } from "./interfaces/IPythOracle.sol";

/**
 * @title PythOracle Contract
 *
 * @notice Oracle contract that fetches and normalizes price data from Pyth Network.
 *
 * @dev Implements IPythOracle interface and uses Pyth Network as price feed source.
 * @dev This contract inherits functionalities from `Initializable` and `Ownable2StepUpgradeable`.
 *
 * @author Hovooo (@hovooo)
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract PythOracle is IPythOracle, Initializable, Ownable2StepUpgradeable {
    // -- State variables --

    /**
     * @notice Address of the token the oracle is for.
     */
    address public override underlying;

    /**
     * @notice Pyth Oracle address.
     */
    address public override pyth;

    /**
     * @notice  Pyth's priceId used to determine the price of the `underlying`.
     */
    bytes32 public override priceId;

    /**
     * @notice Allowed age of the returned price in seconds.
     */
    uint256 public override age;

    /**
     * @notice The standard decimal precision (18) used for price normalization across the protocol.
     */
    uint256 public constant override ALLOWED_DECIMALS = 18;

    /**
     * @notice The minimum confidence percentage.
     * @dev Uses 2 decimal precision, where 1% is represented as 100.
     */
    uint256 public override MIN_CONFIDENCE_PERCENTAGE = 300;

    /**
     * @notice The precision to be used for the confidence percentage to avoid precision loss.
     */
    uint256 public constant override CONFIDENCE_PRECISION = 1e4;

    // -- Constructor --

    constructor() {
        _disableInitializers();
    }

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
    ) public initializer {
        __Ownable_init(_initialOwner);
        __Ownable2Step_init();

        // Emit the event before state changes to track oracle deployments and configurations
        emit PythOracleCreated({ underlying: _underlying, priceId: _priceId, age: _age });

        // Initialize oracle configuration parameters
        underlying = _underlying;
        pyth = _pyth;
        priceId = _priceId;
        age = _age;
    }

    // -- Administration --

    /**
     * @notice Updates the age to a new value.
     * @dev Only the contract owner can call this function.
     * @param _newAge The new age to be set.
     */
    function updateAge(
        uint256 _newAge
    ) external override onlyOwner {
        if (_newAge == 0) revert InvalidAge();
        if (_newAge == age) revert InvalidAge();

        // Emit the event before modifying the state to provide a reliable record of the oracle's age update operation.
        emit AgeUpdated({ oldValue: age, newValue: _newAge });
        age = _newAge;
    }

    /**
     * @notice Updates the confidence percentage to a new value.
     * @dev Only the contract owner can call this function.
     * @param _newConfidence The new confidence percentage to be set.
     */
    function updateConfidencePercentage(
        uint256 _newConfidence
    ) external override onlyOwner {
        if (_newConfidence == 0) revert InvalidConfidencePercentage();
        if (_newConfidence == MIN_CONFIDENCE_PERCENTAGE) revert InvalidConfidencePercentage();
        if (_newConfidence > CONFIDENCE_PRECISION) revert InvalidConfidencePercentage();

        // Emit the event before modifying the state to provide a reliable record of the oracle's confidence percentage
        // update operation.
        emit ConfidencePercentageUpdated({ oldValue: MIN_CONFIDENCE_PERCENTAGE, newValue: _newConfidence });
        MIN_CONFIDENCE_PERCENTAGE = _newConfidence;
    }

    // -- Getters --

    /**
     * @notice Fetches the latest exchange rate without causing any state changes.
     *
     * @dev The function attempts to retrieve the price from the Pyth oracle. It ensures that the price
     * does not violate constraints such as being negative or having an invalid exponent. Any failure in fetching the
     * price results in the function returning a failure status and a zero rate.
     *
     * @return success Indicates whether a valid (recent) rate was retrieved. Returns false if no valid rate available.
     * @return rate The normalized exchange rate of the requested asset pair, expressed with `ALLOWED_DECIMALS`.
     */
    function peek(
        bytes calldata
    ) external view returns (bool success, uint256 rate) {
        try IPyth(pyth).getPriceNoOlderThan({ id: priceId, age: age }) returns (PythStructs.Price memory price) {
            // Ensure the fetched price is not negative
            if (price.price <= 0) revert InvalidOraclePrice();

            // Disallow excessively large prices by rejecting positive exponents
            if (price.expo > 0) revert ExpoTooBig();

            // Safely converts negative exponent to an unsigned integer.
            uint256 invertedExpo = uint256(-int256(price.expo));

            // Prevent underflow when normalizing the price to ALLOWED_DECIMALS
            if (invertedExpo > ALLOWED_DECIMALS) revert ExpoTooSmall();

            // Consider whether the price spread is too high
            uint256 confDecimals = 10 ** invertedExpo;
            bool isConfident = price.conf * confDecimals / uint64(price.price)
                <= MIN_CONFIDENCE_PERCENTAGE * confDecimals / CONFIDENCE_PRECISION;

            // Calculate the actual price based on the confidence
            uint256 priceWithConfidence =
                isConfident ? uint256(uint64(price.price)) : uint256((uint64(price.price)) - price.conf);

            // Normalize the price to ALLOWED_DECIMALS (e.g., 18 decimals)
            rate = priceWithConfidence * 10 ** (ALLOWED_DECIMALS - invertedExpo);
            success = true;
        } catch {
            // Handle any failure in fetching the price by returning false and a zero rate
            success = false;
            rate = 0;
        }
    }

    /**
     * @notice Returns a human readable name of the underlying of the oracle.
     */
    function name() external view override returns (string memory) {
        return IERC20Metadata(underlying).name();
    }

    /**
     * @notice Returns a human readable symbol of the underlying of the oracle.
     */
    function symbol() external view override returns (string memory) {
        return IERC20Metadata(underlying).symbol();
    }

    /**
     * @dev Renounce ownership override to avoid losing contract's ownership.
     */
    function renounceOwnership() public pure override {
        revert("1000");
    }
}
