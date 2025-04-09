// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IOracle } from "../oracle/IOracle.sol";
import { IManager } from "./IManager.sol";

/**
 * @title ISharesRegistry
 * @dev Interface for the Shares Registry Contract.
 * @dev Based on MIM CauldraonV2 contract.
 */
interface ISharesRegistry {
    /**
     * @notice Configuration struct for registry parameters.
     * @dev Used to store key parameters that control collateral and liquidation behavior.
     *
     * @param collateralizationRate The minimum collateral ratio required, expressed as a percentage with precision.
     * @param liquidationBuffer Is a value, that represents the buffer between the collateralization rate and the
     * liquidation threshold, upon which the liquidation is allowed.
     * @param liquidatorBonus The bonus percentage given to liquidators as incentive, expressed with precision.
     */
    struct RegistryConfig {
        uint256 collateralizationRate;
        uint256 liquidationBuffer;
        uint256 liquidatorBonus;
    }

    /**
     * @notice Event emitted when borrowed amount is set.
     * @param _holding The address of the holding.
     * @param oldVal The old value.
     * @param newVal The new value.
     */
    event BorrowedSet(address indexed _holding, uint256 oldVal, uint256 newVal);

    /**
     * @notice Event emitted when collateral is registered.
     * @param user The address of the user.
     * @param share The amount of shares.
     */
    event CollateralAdded(address indexed user, uint256 share);

    /**
     * @notice Event emitted when collateral was unregistered.
     * @param user The address of the user.
     * @param share The amount of shares.
     */
    event CollateralRemoved(address indexed user, uint256 share);

    /**
     * @notice Event emitted when the collateralization rate is updated.
     * @param oldVal The old value.
     * @param newVal The new value.
     */
    event CollateralizationRateUpdated(uint256 oldVal, uint256 newVal);

    /**
     * @notice Event emitted when a new oracle is requested.
     * @param newOracle The new oracle address.
     */
    event NewOracleRequested(address newOracle);

    /**
     * @notice Event emitted when the oracle is updated.
     */
    event OracleUpdated();

    /**
     * @notice Event emitted when new oracle data is requested.
     * @param newData The new data.
     */
    event NewOracleDataRequested(bytes newData);

    /**
     * @notice Event emitted when oracle data is updated.
     */
    event OracleDataUpdated();

    /**
     * @notice Event emitted when a new timelock amount is requested.
     * @param oldVal The old value.
     * @param newVal The new value.
     */
    event TimelockAmountUpdateRequested(uint256 oldVal, uint256 newVal);

    /**
     * @notice Event emitted when timelock amount is updated.
     * @param oldVal The old value.
     * @param newVal The new value.
     */
    event TimelockAmountUpdated(uint256 oldVal, uint256 newVal);

    /**
     * @notice Event emitted when the config is updated.
     * @param token The token address.
     * @param oldVal The old config.
     * @param newVal The new config.
     */
    event ConfigUpdated(address indexed token, RegistryConfig oldVal, RegistryConfig newVal);

    /**
     * @notice Returns holding's borrowed amount.
     * @param _holding The address of the holding.
     * @return The borrowed amount.
     */
    function borrowed(
        address _holding
    ) external view returns (uint256);

    /**
     * @notice Returns holding's available collateral amount.
     * @param _holding The address of the holding.
     * @return The collateral amount.
     */
    function collateral(
        address _holding
    ) external view returns (uint256);

    /**
     * @notice Returns the token address for which this registry was created.
     * @return The token address.
     */
    function token() external view returns (address);

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     * @return The manager contract.
     */
    function manager() external view returns (IManager);

    /**
     * @notice Oracle contract associated with this share registry.
     * @return The oracle contract.
     */
    function oracle() external view returns (IOracle);

    /**
     * @notice Extra oracle data if needed.
     * @return The oracle data.
     */
    function oracleData() external view returns (bytes calldata);

    /**
     * @notice Current timelock amount.
     * @return The timelock amount.
     */
    function timelockAmount() external view returns (uint256);

    // -- User specific methods --

    /**
     * @notice Updates `_holding`'s borrowed amount.
     *
     * @notice Requirements:
     * - `msg.sender` must be the Stables Manager Contract.
     * - `_newVal` must be greater than or equal to the minimum debt amount.
     *
     * @notice Effects:
     * - Updates `borrowed` mapping.
     *
     * @notice Emits:
     * - `BorrowedSet` indicating holding's borrowed amount update operation.
     *
     * @param _holding The address of the user's holding.
     * @param _newVal The new borrowed amount.
     */
    function setBorrowed(address _holding, uint256 _newVal) external;

    /**
     * @notice Registers collateral for user's `_holding`.
     *
     * @notice Requirements:
     * - `msg.sender` must be the Stables Manager Contract.
     *
     * @notice Effects:
     * - Updates `collateral` mapping.
     *
     * @notice Emits:
     * - `CollateralAdded` event indicating collateral addition operation.
     *
     * @param _holding The address of the user's holding.
     * @param _share The new collateral shares.
     */
    function registerCollateral(address _holding, uint256 _share) external;

    /**
     * @notice Registers a collateral removal operation for user's `_holding`.
     *
     * @notice Requirements:
     * - `msg.sender` must be the Stables Manager Contract.
     *
     * @notice Effects:
     * - Updates `collateral` mapping.
     *
     * @notice Emits:
     * - `CollateralRemoved` event indicating collateral removal operation.
     *
     * @param _holding The address of the user's holding.
     * @param _share The new collateral shares.
     */
    function unregisterCollateral(address _holding, uint256 _share) external;

    // -- Administration --

    /**
     * @notice Updates the registry configuration parameters.
     *
     * @notice Effects:
     * - Updates `config` state variable.
     *
     * @notice Emits:
     * - `ConfigUpdated` event indicating config update operation.
     *
     * @param _newConfig The new configuration parameters.
     */
    function updateConfig(
        RegistryConfig memory _newConfig
    ) external;

    /**
     * @notice Requests a change for the oracle address.
     *
     * @notice Requirements:
     * - Previous oracle change request must have expired or been accepted.
     * - No timelock or oracle data change requests should be active.
     * - `_oracle` must not be the zero address.
     *
     * @notice Effects:
     * - Updates `_isOracleActiveChange` state variable.
     * - Updates `_newOracle` state variable.
     * - Updates `_newOracleTimestamp` state variable.
     *
     * @notice Emits:
     * - `NewOracleRequested` event indicating new oracle request.
     *
     * @param _oracle The new oracle address.
     */
    function requestNewOracle(
        address _oracle
    ) external;

    /**
     * @notice Updates the oracle.
     *
     * @notice Requirements:
     * - Oracle change must have been requested and the timelock must have passed.
     *
     * @notice Effects:
     * - Updates `oracle` state variable.
     * - Updates `_isOracleActiveChange` state variable.
     * - Updates `_newOracle` state variable.
     * - Updates `_newOracleTimestamp` state variable.
     *
     * @notice Emits:
     * - `OracleUpdated` event indicating oracle update.
     */
    function setOracle() external;

    /**
     * @notice Requests a change for oracle data.
     *
     * @notice Requirements:
     * - Previous oracle data change request must have expired or been accepted.
     * - No timelock or oracle change requests should be active.
     *
     * @notice Effects:
     * - Updates `_isOracleDataActiveChange` state variable.
     * - Updates `_newOracleData` state variable.
     * - Updates `_newOracleDataTimestamp` state variable.
     *
     * @notice Emits:
     * - `NewOracleDataRequested` event indicating new oracle data request.
     *
     * @param _data The new oracle data.
     */
    function requestNewOracleData(
        bytes calldata _data
    ) external;

    /**
     * @notice Updates the oracle data.
     *
     * @notice Requirements:
     * - Oracle data change must have been requested and the timelock must have passed.
     *
     * @notice Effects:
     * - Updates `oracleData` state variable.
     * - Updates `_isOracleDataActiveChange` state variable.
     * - Updates `_newOracleData` state variable.
     * - Updates `_newOracleDataTimestamp` state variable.
     *
     * @notice Emits:
     * - `OracleDataUpdated` event indicating oracle data update.
     */
    function setOracleData() external;

    /**
     * @notice Requests a timelock update.
     *
     * @notice Requirements:
     * - `_newVal` must not be zero.
     * - Previous timelock change request must have expired or been accepted.
     * - No oracle or oracle data change requests should be active.
     *
     * @notice Effects:
     * - Updates `_isTimelockActiveChange` state variable.
     * - Updates `_oldTimelock` state variable.
     * - Updates `_newTimelock` state variable.
     * - Updates `_newTimelockTimestamp` state variable.
     *
     * @notice Emits:
     * - `TimelockAmountUpdateRequested` event indicating timelock change request.
     *
     * @param _newVal The new value in seconds.
     */
    function requestTimelockAmountChange(
        uint256 _newVal
    ) external;

    /**
     * @notice Updates the timelock amount.
     *
     * @notice Requirements:
     * - Timelock change must have been requested and the timelock must have passed.
     * - The timelock for timelock change must have already expired.
     *
     * @notice Effects:
     * - Updates `timelockAmount` state variable.
     * - Updates `_oldTimelock` state variable.
     * - Updates `_newTimelock` state variable.
     * - Updates `_newTimelockTimestamp` state variable.
     *
     * @notice Emits:
     * - `TimelockAmountUpdated` event indicating timelock amount change operation.
     */
    function acceptTimelockAmountChange() external;

    // -- Getters --

    /**
     * @notice Returns the up to date exchange rate of the `token`.
     *
     * @notice Requirements:
     * - Oracle must provide an updated rate.
     *
     * @return The updated exchange rate.
     */
    function getExchangeRate() external view returns (uint256);

    /**
     * @notice Returns the configuration parameters for the registry.
     * @return The RegistryConfig struct containing the parameters.
     */
    function getConfig() external view returns (RegistryConfig memory);
}
