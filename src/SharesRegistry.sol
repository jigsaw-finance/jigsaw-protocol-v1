// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IManager } from "./interfaces/core/IManager.sol";
import { ISharesRegistry } from "./interfaces/core/ISharesRegistry.sol";
import { IStablesManager } from "./interfaces/core/IStablesManager.sol";
import { IOracle } from "./interfaces/oracle/IOracle.sol";

/**
 * @title SharesRegistry
 *
 * @notice Registers, manages and tracks assets used as collaterals within the Jigsaw Protocol.
 *
 * @author Hovooo (@hovooo), Cosmin Grigore (@gcosmintech).
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract SharesRegistry is ISharesRegistry, Ownable2Step {
    /**
     * @notice Returns the token address for which this registry was created.
     */
    address public immutable override token;

    /**
     * @notice Returns holding's borrowed amount.
     */
    mapping(address holding => uint256 amount) public override borrowed;

    /**
     * @notice Returns holding's available collateral amount.
     */
    mapping(address holding => uint256 amount) public override collateral;

    /**
     * /**
     * @notice Contract that contains the address of the Manager Contract.
     */
    IManager public override manager;

    /**
     * @notice Configuration parameters for the registry.
     * @dev Stores collateralization rate, liquidation threshold, and liquidator bonus.
     */
    RegistryConfig private config;

    /**
     * @notice Minimal collateralization rate acceptable for registry to avoid computational errors.
     * @dev 20e3 means 20% LTV.
     */
    uint16 private immutable minCR = 20e3;

    /**
     * @notice Maximum liquidation buffer acceptable for registry to avoid computational errors.
     * @dev 20e3 means 20% buffer.
     */
    uint16 private immutable maxLiquidationBuffer = 20e3;

    /**
     * @notice Oracle contract associated with this share registry.
     */
    IOracle public override oracle;
    address private _newOracle;
    uint256 private _newOracleTimestamp;

    /**
     * @notice Extra oracle data if needed.
     */
    bytes public override oracleData;
    bytes private _newOracleData;
    uint256 private _newOracleDataTimestamp;

    /**
     * @notice Timelock amount in seconds for changing the oracle data.
     */
    uint256 public override timelockAmount = 1 hours;
    uint256 private _oldTimelock;
    uint256 private _newTimelock;
    uint256 private _newTimelockTimestamp;

    bool private _isOracleActiveChange = false;
    bool private _isOracleDataActiveChange = false;
    bool private _isTimelockActiveChange = false;

    /**
     * @notice Creates a SharesRegistry for a specific token.
     *
     * @param _initialOwner The initial owner of the contract.
     * @param _manager Contract that holds all the necessary configs of the protocol.
     * @param _token The address of the token contract, used as a collateral within this contract.
     * @param _oracle The oracle used to retrieve price data for the `_token`.
     * @param _oracleData Extra data for the oracle.
     * @param _config Configuration parameters for the registry.
     */
    constructor(
        address _initialOwner,
        address _manager,
        address _token,
        address _oracle,
        bytes memory _oracleData,
        RegistryConfig memory _config
    ) Ownable(_initialOwner) {
        require(_manager != address(0), "3065");
        require(_token != address(0), "3001");
        require(_oracle != address(0), "3034");

        token = _token;
        oracle = IOracle(_oracle);
        oracleData = _oracleData;
        manager = IManager(_manager);

        _updateConfig(_config);
    }

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
    function setBorrowed(address _holding, uint256 _newVal) external override onlyStableManager {
        // Ensure the `holding` holds allowed minimum jUSD debt amount
        require(_newVal == 0 || _newVal >= manager.minDebtAmount(), "3102");
        // Emit event indicating successful update
        emit BorrowedSet({ _holding: _holding, oldVal: borrowed[_holding], newVal: _newVal });
        // Update the borrowed amount for the holding
        borrowed[_holding] = _newVal;
    }

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
    function registerCollateral(address _holding, uint256 _share) external override onlyStableManager {
        collateral[_holding] += _share;
        emit CollateralAdded({ user: _holding, share: _share });
    }

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
    function unregisterCollateral(address _holding, uint256 _share) external override onlyStableManager {
        if (_share > collateral[_holding]) {
            _share = collateral[_holding];
        }
        collateral[_holding] = collateral[_holding] - _share;
        emit CollateralRemoved(_holding, _share);
    }

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
    ) external override onlyOwner {
        _updateConfig(_newConfig);
    }

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
    ) external override onlyOwner {
        if (_newOracleTimestamp + timelockAmount > block.timestamp) require(!_isOracleActiveChange, "3093");
        require(!_isTimelockActiveChange, "3095");
        require(_oracle != address(0), "3000");

        _isOracleActiveChange = true;
        _newOracle = _oracle;
        _newOracleTimestamp = block.timestamp;
        emit NewOracleRequested(_oracle);
    }

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
    function setOracle() external override onlyOwner {
        require(_isOracleActiveChange, "3094");
        require(_newOracleTimestamp + timelockAmount <= block.timestamp, "3066");

        oracle = IOracle(_newOracle);
        _isOracleActiveChange = false;
        _newOracle = address(0);
        _newOracleTimestamp = 0;
        emit OracleUpdated();
    }

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
    ) external override onlyOwner {
        if (_newOracleDataTimestamp + timelockAmount > block.timestamp) require(!_isOracleDataActiveChange, "3096");
        require(!_isTimelockActiveChange, "3095");

        _isOracleDataActiveChange = true;
        _newOracleData = _data;
        _newOracleDataTimestamp = block.timestamp;
        emit NewOracleDataRequested(_newOracleData);
    }

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
    function setOracleData() external override onlyOwner {
        require(_isOracleDataActiveChange, "3094");
        require(_newOracleDataTimestamp + timelockAmount <= block.timestamp, "3066");

        oracleData = _newOracleData;
        _isOracleDataActiveChange = false;
        delete _newOracleData;
        _newOracleDataTimestamp = 0;
        emit OracleDataUpdated();
    }

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
    ) external override onlyOwner {
        if (_newTimelockTimestamp + _oldTimelock > block.timestamp) require(!_isTimelockActiveChange, "3095");
        require(!_isOracleActiveChange, "3093");
        require(!_isOracleDataActiveChange, "3096");
        require(_newVal != 0, "2001");

        _isTimelockActiveChange = true;
        _oldTimelock = timelockAmount;
        _newTimelock = _newVal;
        _newTimelockTimestamp = block.timestamp;
        emit TimelockAmountUpdateRequested(_oldTimelock, _newTimelock);
    }

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
    function acceptTimelockAmountChange() external override onlyOwner {
        require(_isTimelockActiveChange, "3094");
        require(_newTimelockTimestamp + _oldTimelock <= block.timestamp, "3066");

        timelockAmount = _newTimelock;
        emit TimelockAmountUpdated(_oldTimelock, _newTimelock);
        _oldTimelock = 0;
        _newTimelock = 0;
        _newTimelockTimestamp = 0;

        _isTimelockActiveChange = false;
    }

    // -- Getters --

    /**
     * @notice Returns the up to date exchange rate of the `token`.
     *
     * @notice Requirements:
     * - Oracle must provide an updated rate.
     *
     * @return The updated exchange rate.
     */
    function getExchangeRate() external view override returns (uint256) {
        (bool updated, uint256 rate) = oracle.peek(oracleData);
        require(updated, "3037");
        require(rate > 0, "2100");

        return rate;
    }

    /**
     * @notice Returns the configuration parameters for the registry.
     * @return The RegistryConfig struct containing the parameters.
     */
    function getConfig() external view override returns (RegistryConfig memory) {
        return config;
    }

    // -- Private methods --

    /**
     * @notice Updates the configuration parameters for the registry.
     * @param _config The new configuration parameters.
     */
    function _updateConfig(
        RegistryConfig memory _config
    ) private {
        uint256 precision = manager.PRECISION();

        require(_config.collateralizationRate >= minCR && _config.collateralizationRate <= precision, "3066");
        require(_config.liquidationBuffer <= maxLiquidationBuffer, "3100");

        uint256 maxLiquidatorBonus = precision - _config.collateralizationRate - _config.liquidationBuffer;
        require(_config.liquidatorBonus <= maxLiquidatorBonus, "3101");

        emit ConfigUpdated(token, config, _config);
        config = _config;
    }

    // -- Modifiers --

    /**
     * @notice Modifier to only allow access to a function by the Stables Manager Contract.
     */
    modifier onlyStableManager() {
        require(msg.sender == manager.stablesManager(), "1000");
        _;
    }
}
