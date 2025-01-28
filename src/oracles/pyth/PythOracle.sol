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
 * @dev Implements IPythOracle interface and uses Pyth Network as price feed source.
 *
 * @dev This contract inherits functionalities from `Initializable` and `Ownable2StepUpgradeable`.
 *
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
     * @notice The standard decimal precision (18) used for price normalization across the protocol
     */
    uint256 private constant ALLOWED_DECIMALS = 18;

    // -- Constructor --

    constructor() {
        _disableInitializers();
    }

    // -- Initialization --

    /**
     * @notice Initializes the Oracle contract with necessary parameters.
     */
    function initialize(
        InitializerParams memory _params
    ) public initializer {
        __Ownable_init(_params.initialOwner);
        __Ownable2Step_init();

        // Emit the event before state changes to track oracle deployments and configurations
        emit PythOracleCreated({ underlying: _params.underlying, priceId: _params.priceId, age: _params.age });

        // Initialize oracle configuration parameters
        underlying = _params.underlying;
        pyth = _params.pyth;
        priceId = _params.priceId;
        age = _params.age;
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

        // Emit the event before modifying the state to provide a reliable record of the oracle's age update operation.
        emit AgeUpdated({ oldValue: age, newValue: _newAge });
        age = _newAge;
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
            if (price.price < 0) revert NegativeOraclePrice();

            // Disallow excessively large prices by rejecting positive exponents
            if (price.expo > 0) revert ExpoTooBig();

            // Prevent underflow when normalizing the price to ALLOWED_DECIMALS
            if (uint256(int256(price.expo)) > ALLOWED_DECIMALS) revert ExpoTooSmall();

            // Normalize the price to ALLOWED_DECIMALS (e.g., 18 decimals)
            // Formula: price * 10^(ALLOWED_DECIMALS - expo)
            // Example: If price = 1234, expo = -8, ALLOWED_DECIMALS = 18
            // Result: 1234 * 10^(18 - uint256(-8)) = 1234 * 10^10
            rate = uint256(int256(price.price)) * 10 ** (ALLOWED_DECIMALS - uint256(int256(price.expo)));
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
}
