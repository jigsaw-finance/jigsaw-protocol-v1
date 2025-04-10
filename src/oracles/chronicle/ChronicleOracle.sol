// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IChronicleMinimal } from "./interfaces/IChronicleMinimal.sol";
import { IChronicleOracle } from "./interfaces/IChronicleOracle.sol";

/**
 * @title ChronicleOracle Contract
 *
 * @notice Oracle contract that fetches price data from Chronicle Oracle.
 *
 * @dev Implements IChronicleOracle interface and uses Chronicle Protocol as price feed source.
 * @dev This contract inherits functionalities from `Initializable` and `Ownable2StepUpgradeable`.
 *
 * @author Hovooo (@hovooo)
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract ChronicleOracle is IChronicleOracle, Initializable, Ownable2StepUpgradeable {
    // -- State variables --

    /**
     * @notice Address of the token the oracle is for.
     */
    address public override underlying;

    /**
     * @notice Chronicle Oracle address.
     */
    address public override chronicle;

    /**
     * @notice Allowed age of the returned price in seconds.
     */
    uint256 public override ageValidityPeriod;

    /**
     * @notice Buffer to account for the age of the price.
     * @dev This is used to ensure that the price is not considered outdated if it is within the buffer allowed for the
     * Chronicle protocol to update the price on-chain.
     */
    uint256 public override ageValidityBuffer;

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
     * @param _chronicle The Address of the Chronicle Oracle.
     * @param _ageValidityPeriod The Age in seconds after which the price is considered invalid.
     */
    function initialize(
        address _initialOwner,
        address _underlying,
        address _chronicle,
        uint256 _ageValidityPeriod
    ) public initializer {
        __Ownable_init(_initialOwner);
        __Ownable2Step_init();

        // Emit the event before state changes to track oracle deployments and configurations
        emit ChronicleOracleCreated({
            underlying: _underlying,
            chronicle: _chronicle,
            ageValidityPeriod: _ageValidityPeriod
        });

        // Initialize oracle configuration parameters
        underlying = _underlying;
        chronicle = _chronicle;
        ageValidityPeriod = _ageValidityPeriod;
        ageValidityBuffer = 15 minutes;
    }

    // -- Administration --

    /**
     * @notice Updates the age validity period to a new value.
     * @dev Only the contract owner can call this function.
     * @param _newAgeValidityPeriod The new age validity period to be set.
     */
    function updateAgeValidityPeriod(
        uint256 _newAgeValidityPeriod
    ) external override onlyOwner {
        if (_newAgeValidityPeriod == 0) revert InvalidAgeValidityPeriod();
        if (_newAgeValidityPeriod == ageValidityPeriod) revert InvalidAgeValidityPeriod();

        // Emit the event before modifying the state to provide a reliable record of the oracle's age update operation.
        emit AgeValidityPeriodUpdated({ oldValue: ageValidityPeriod, newValue: _newAgeValidityPeriod });
        ageValidityPeriod = _newAgeValidityPeriod;
    }

    // -- Getters --

    /**
     * @notice Fetches the latest exchange rate without causing any state changes.
     *
     * @dev The function attempts to retrieve the price from the Chronicle oracle. It ensures that the price
     * does not violate constraints such as being negative or having an invalid exponent. Any failure in fetching the
     * price results in the function returning a failure status and a zero rate.
     *
     * @return success Indicates whether a valid (recent) rate was retrieved. Returns false if no valid rate available.
     * @return rate The normalized exchange rate of the requested asset pair, expressed with `ALLOWED_DECIMALS`.
     */
    function peek(
        bytes calldata
    ) external view returns (bool success, uint256 rate) {
        try IChronicleMinimal(chronicle).readWithAge() returns (uint256 value, uint256 age) {
            // Ensure the fetched price is not zero
            if (value == 0) revert ZeroPrice();

            // Ensure the price is not outdated
            uint256 minAllowedAge = block.timestamp - (ageValidityPeriod + ageValidityBuffer);
            if (age < minAllowedAge) revert OutdatedPrice({ minAllowedAge: minAllowedAge, actualAge: age });

            // Set success flag and return the price
            success = true;
            rate = value;
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
