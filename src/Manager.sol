// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { ILiquidationManager } from "./interfaces/core/ILiquidationManager.sol";
import { IManager } from "./interfaces/core/IManager.sol";
import { IOracle } from "./interfaces/oracle/IOracle.sol";
import { OperationsLib } from "./libraries/OperationsLib.sol";

/**
 * @title Manager
 *
 * @notice This contract manages various configurations necessary for the functioning of the protocol.
 *
 * @dev This contract inherits functionalities from `Ownable2Step`.
 *
 * @author Hovooo (@hovooo), Cosmin Grigore (@gcosmintech).
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract Manager is IManager, Ownable2Step {
    // -- Mappings --

    /**
     * @notice Returns true/false for contracts' whitelist status.
     */
    mapping(address caller => bool whitelisted) public override isContractWhitelisted;

    /**
     * @notice Returns true if token is whitelisted.
     */
    mapping(address token => bool whitelisted) public override isTokenWhitelisted;

    /**
     * @notice Returns true if the token cannot be withdrawn from a holding.
     */
    mapping(address token => bool withdrawable) public override isTokenNonWithdrawable;

    /**
     * @notice Returns true if caller is allowed invoker.
     */
    mapping(address invoker => bool allowed) public override allowedInvokers;

    // -- Essential tokens --

    /**
     * @notice USDC address.
     */
    address public immutable override USDC;

    /**
     * @notice WETH address.
     */
    address public immutable override WETH;

    // -- Protocol's stablecoin oracle config --

    /**
     * @notice Oracle contract associated with protocol's stablecoin.
     */
    IOracle public override jUsdOracle;

    /**
     * @notice Extra oracle data if needed.
     */
    bytes public override oracleData;

    // -- Managers --

    /**
     * @notice Returns the address of the HoldingManager Contract.
     */
    address public override holdingManager;

    /**
     * @notice Returns the address of the LiquidationManager Contract.
     */
    address public override liquidationManager;

    /**
     * @notice Returns the address of the StablesManager Contract.
     */
    address public override stablesManager;

    /**
     * @notice Returns the address of the StrategyManager Contract.
     */
    address public override strategyManager;

    /**
     * @notice Returns the address of the SwapManager Contract.
     */
    address public override swapManager;

    // -- Fees --

    /**
     * @notice Returns the default performance fee.
     * @dev Uses 2 decimal precision, where 1% is represented as 100.
     */
    uint256 public override performanceFee = 1500; //15%

    /**
     * @notice Fee for withdrawing from a holding.
     * @dev Uses 2 decimal precision, where 1% is represented as 100.
     */
    uint256 public override withdrawalFee;

    /**
     * @notice The % amount a liquidator gets.
     * @dev Uses 3 decimal precision, where 1% is represented as 1000.
     * @dev 8% is the default liquidator's bonus.
     */
    uint256 public override liquidatorBonus = 8e3;

    /**
     * @notice The max % amount the protocol gets when a self-liquidation operation happens.
     * @dev Uses 3 decimal precision, where 1% is represented as 1000.
     * @dev 8% is the default self-liquidation fee.
     */
    uint256 public override selfLiquidationFee = 8e3;

    /**
     * @notice Returns the fee address, where all the fees are collected.
     */
    address public override feeAddress;

    // -- Factories --

    /**
     * @notice Returns the address of the ReceiptTokenFactory.
     */
    address public override receiptTokenFactory;

    // -- Utility values --

    /**
     * @notice Flag indicating whether the Manager Contract is in the active change state.
     */
    bool private _isActiveChange = false;

    /**
     * @notice Returns the collateral rate precision.
     * @dev Should be less than exchange rate precision due to optimization in math.
     */
    uint256 public constant override PRECISION = 1e5;

    /**
     * @notice Returns the exchange rate precision.
     */
    uint256 public constant override EXCHANGE_RATE_PRECISION = 1e18;

    /**
     * @notice Timelock amount in seconds for changing the oracle data.
     */
    uint256 public override timelockAmount = 1 hours;

    /**
     * @notice Variables required for delayed timelock update.
     */
    uint256 private _oldTimelock;
    uint256 private _newTimelock;
    uint256 private _newTimelockTimestamp;

    /**
     * @notice Variables required for delayed oracle update.
     */
    address private _newOracle;
    uint256 private _newOracleTimestamp;

    /**
     * @notice Creates a new Manager Contract.
     *
     * @param _initialOwner The initial owner of the contract.
     * @param _usdc The USDC address.
     * @param _weth The WETH address.
     * @param _oracle The jUSD oracle address.
     * @param _oracleData The jUSD initial oracle data.
     */
    constructor(
        address _initialOwner,
        address _usdc,
        address _weth,
        address _oracle,
        bytes memory _oracleData
    ) Ownable(_initialOwner) validAddress(_usdc) validAddress(_weth) validAddress(_oracle) {
        USDC = _usdc;
        WETH = _weth;
        jUsdOracle = IOracle(_oracle);
        oracleData = _oracleData;
    }

    // -- Setters --

    /**
     * @notice Whitelists a contract.
     *
     * @notice Requirements:
     * - `_contract` must not be whitelisted.
     *
     * @notice Effects:
     * - Updates the `isContractWhitelisted` mapping.
     *
     * @notice Emits:
     * - `ContractWhitelisted` event indicating successful contract whitelist operation.
     *
     * @param _contract The address of the contract to be whitelisted.
     */
    function whitelistContract(
        address _contract
    ) external override onlyOwner validAddress(_contract) {
        require(!isContractWhitelisted[_contract], "3019");
        isContractWhitelisted[_contract] = true;
        emit ContractWhitelisted(_contract);
    }

    /**
     * @notice Blacklists a contract.
     *
     * @notice Requirements:
     * - `_contract` must be whitelisted.
     *
     * @notice Effects:
     * - Updates the `isContractWhitelisted` mapping.
     *
     * @notice Emits:
     * - `ContractBlacklisted` event indicating successful contract blacklist operation.
     *
     * @param _contract The address of the contract to be blacklisted.
     */
    function blacklistContract(
        address _contract
    ) external override onlyOwner validAddress(_contract) {
        require(isContractWhitelisted[_contract], "1000");
        isContractWhitelisted[_contract] = false;
        emit ContractBlacklisted(_contract);
    }

    /**
     * @notice Whitelists a token.
     *
     * @notice Requirements:
     * - `_token` must not be whitelisted.
     *
     * @notice Effects:
     * - Updates the `isTokenWhitelisted` mapping.
     *
     * @notice Emits:
     * - `TokenWhitelisted` event indicating successful token whitelist operation.
     *
     * @param _token The address of the token to be whitelisted.
     */
    function whitelistToken(
        address _token
    ) external override onlyOwner validAddress(_token) {
        require(!isTokenWhitelisted[_token], "3019");
        isTokenWhitelisted[_token] = true;
        emit TokenWhitelisted(_token);
    }

    /**
     * @notice Removes a token from whitelist.
     *
     * @notice Requirements:
     * - `_token` must be whitelisted.
     *
     * @notice Effects:
     * - Updates the `isTokenWhitelisted` mapping.
     *
     * @notice Emits:
     * - `TokenRemoved` event indicating successful token removal operation.
     *
     * @param _token The address of the token to be whitelisted.
     */
    function removeToken(
        address _token
    ) external override onlyOwner validAddress(_token) {
        require(isTokenWhitelisted[_token], "1000");
        isTokenWhitelisted[_token] = false;
        emit TokenRemoved(_token);
    }

    /**
     * @notice Registers the `_token` as non-withdrawable.
     *
     * @notice Requirements:
     * - `msg.sender` must be owner or `strategyManager`.
     * - `_token` must not be non-withdrawable.
     *
     * @notice Effects:
     * - Updates the `isTokenNonWithdrawable` mapping.
     *
     * @notice Emits:
     * - `NonWithdrawableTokenAdded` event indicating successful non-withdrawable token addition operation.
     *
     * @param _token The address of the token to be added as non-withdrawable.
     */
    function addNonWithdrawableToken(
        address _token
    ) external override validAddress(_token) {
        require(owner() == msg.sender || strategyManager == msg.sender, "1000");
        require(!isTokenNonWithdrawable[_token], "3069");
        isTokenNonWithdrawable[_token] = true;
        emit NonWithdrawableTokenAdded(_token);
    }

    /**
     * @notice Unregisters the `_token` as non-withdrawable.
     *
     * @notice Requirements:
     * - `_token` must be non-withdrawable.
     *
     * @notice Effects:
     * - Updates the `isTokenNonWithdrawable` mapping.
     *
     * @notice Emits:
     * - `NonWithdrawableTokenRemoved` event indicating successful non-withdrawable token removal operation.
     *
     * @param _token The address of the token to be removed as non-withdrawable.
     */
    function removeNonWithdrawableToken(
        address _token
    ) external override onlyOwner validAddress(_token) {
        require(isTokenNonWithdrawable[_token], "3070");
        isTokenNonWithdrawable[_token] = false;
        emit NonWithdrawableTokenRemoved(_token);
    }

    /**
     * @notice Sets invoker as allowed or forbidden.
     *
     * @notice Effects:
     * - Updates the `allowedInvokers` mapping.
     *
     * @notice Emits:
     * - `InvokerUpdated` event indicating successful invoker update operation.
     *
     * @param _component Invoker's address.
     * @param _allowed True/false.
     */
    function updateInvoker(address _component, bool _allowed) external override onlyOwner validAddress(_component) {
        allowedInvokers[_component] = _allowed;
        emit InvokerUpdated(_component, _allowed);
    }

    /**
     * @notice Sets the Holding Manager Contract's address.
     *
     * @notice Requirements:
     * - `_val` must be different from previous `holdingManager` address.
     *
     * @notice Effects:
     * - Updates the `holdingManager` state variable.
     *
     * @notice Emits:
     * - `HoldingManagerUpdated` event indicating the successful setting of the Holding Manager's address.
     *
     * @param _val The holding manager's address.
     */
    function setHoldingManager(
        address _val
    ) external override onlyOwner validAddress(_val) {
        require(holdingManager != _val, "3017");
        emit HoldingManagerUpdated(holdingManager, _val);
        holdingManager = _val;
    }

    /**
     * @notice Sets the Liquidation Manager Contract's address.
     *
     * @notice Requirements:
     * - `_val` must be different from previous `liquidationManager` address.
     *
     * @notice Effects:
     * - Updates the `liquidationManager` state variable.
     *
     * @notice Emits:
     * - `LiquidationManagerUpdated` event indicating the successful setting of the Liquidation Manager's address.
     *
     * @param _val The liquidation manager's address.
     */
    function setLiquidationManager(
        address _val
    ) external override onlyOwner validAddress(_val) {
        require(liquidationManager != _val, "3017");
        emit LiquidationManagerUpdated(liquidationManager, _val);
        liquidationManager = _val;
    }

    /**
     * @notice Sets the Stablecoin Manager Contract's address.
     *
     * @notice Requirements:
     * - `_val` must be different from previous `stablesManager` address.
     *
     * @notice Effects:
     * - Updates the `stablesManager` state variable.
     *
     * @notice Emits:
     * - `StablecoinManagerUpdated` event indicating the successful setting of the Stablecoin Manager's address.
     *
     * @param _val The Stablecoin manager's address.
     */
    function setStablecoinManager(
        address _val
    ) external override onlyOwner validAddress(_val) {
        require(stablesManager != _val, "3017");
        emit StablecoinManagerUpdated(stablesManager, _val);
        stablesManager = _val;
    }

    /**
     * @notice Sets the Strategy Manager Contract's address.
     *
     * @notice Requirements:
     * - `_val` must be different from previous `strategyManager` address.
     *
     * @notice Effects:
     * - Updates the `strategyManager` state variable.
     *
     * @notice Emits:
     * - `StrategyManagerUpdated` event indicating the successful setting of the Strategy Manager's address.
     *
     * @param _val The Strategy manager's address.
     */
    function setStrategyManager(
        address _val
    ) external override onlyOwner validAddress(_val) {
        require(strategyManager != _val, "3017");
        emit StrategyManagerUpdated(strategyManager, _val);
        strategyManager = _val;
    }

    /**
     * @notice Sets the Swap Manager Contract's address.
     *
     * @notice Requirements:
     * - `_val` must be different from previous `swapManager` address.
     *
     * @notice Effects:
     * - Updates the `swapManager` state variable.
     *
     * @notice Emits:
     * - `SwapManagerUpdated` event indicating the successful setting of the Swap Manager's address.
     *
     * @param _val The Swap manager's address.
     */
    function setSwapManager(
        address _val
    ) external override onlyOwner validAddress(_val) {
        require(swapManager != _val, "3017");
        emit SwapManagerUpdated(swapManager, _val);
        swapManager = _val;
    }

    /**
     * @notice Sets the performance fee.
     *
     * @notice Requirements:
     * - `_val` must be smaller than `FEE_FACTOR` to avoid wrong computations.
     *
     * @notice Effects:
     * - Updates the `performanceFee` state variable.
     *
     * @notice Emits:
     * - `PerformanceFeeUpdated` event indicating successful performance fee update operation.
     *
     * @dev `_val` uses 2 decimal precision, where 1% is represented as 100.
     *
     * @param _val The new performance fee value.
     */
    function setPerformanceFee(
        uint256 _val
    ) external override onlyOwner validAmount(_val) {
        require(_val < OperationsLib.FEE_FACTOR, "3018");
        emit PerformanceFeeUpdated(performanceFee, _val);
        performanceFee = _val;
    }

    /**
     * @notice Sets the withdrawal fee.
     *
     * @notice Requirements:
     * - `_val` must be smaller than `FEE_FACTOR` to avoid wrong computations.
     *
     * @notice Effects:
     * - Updates the `withdrawalFee` state variable.
     *
     * @notice Emits:
     * - `WithdrawalFeeUpdated` event indicating successful withdrawal fee update operation.
     *
     * @dev `_val` uses 2 decimal precision, where 1% is represented as 100.
     *
     * @param _val The new withdrawal fee value.
     */
    function setWithdrawalFee(
        uint256 _val
    ) external override onlyOwner {
        require(withdrawalFee != _val, "3017");
        require(_val <= OperationsLib.FEE_FACTOR, "2066");
        emit WithdrawalFeeUpdated(withdrawalFee, _val);
        withdrawalFee = _val;
    }

    /**
     * @notice Sets the liquidator bonus.
     *
     * @notice Requirements:
     * - `_val` must be smaller than `PRECISION` to avoid wrong computations.
     *
     * @notice Effects:
     * - Updates the `liquidatorBonus` state variable.
     * - Updates the `liquidatorBonus` state variable in the LiquidationManager Contract.
     *
     * @notice Emits:
     * - `SwapRouteLiquidatorBonusUpdated` event indicating successful liquidator bonus update operation.
     *
     * @dev `_val` uses 3 decimals precision, where 1000 == 1%.
     *
     * @param _val The new value.
     */
    function setLiquidatorBonus(
        uint256 _val
    ) external override onlyOwner {
        require(_val <= PRECISION, "3066");
        emit LiquidatorBonusUpdated(liquidatorBonus, _val);
        liquidatorBonus = _val;
        ILiquidationManager(liquidationManager).setLiquidatorBonus(_val);
    }

    /**
     * @notice Sets the self-liquidation fee.
     *
     * @notice Requirements:
     * - `_val` must be smaller than `PRECISION` to avoid wrong computations.
     *
     * @notice Effects:
     * - Updates the `selfLiquidationFee` state variable.
     * - Updates the `selfLiquidationFee` state variable in the LiquidationManager Contract.
     *
     * @notice Emits:
     * - `SelfLiquidationFeeUpdated` event indicating successful self-liquidation fee update operation.
     *
     * @dev `_val` uses 3 decimals precision, where 1000 == 1%.
     *
     * @param _val The new value.
     */
    function setSelfLiquidationFee(
        uint256 _val
    ) external override onlyOwner {
        require(_val <= PRECISION, "3066");
        emit SelfLiquidationFeeUpdated(selfLiquidationFee, _val);
        selfLiquidationFee = _val;
        ILiquidationManager(liquidationManager).setSelfLiquidationFee(_val);
    }

    /**
     * @notice Sets the global fee address.
     *
     * @notice Requirements:
     * - `_val` must be different from previous `holdingManager` address.
     *
     * @notice Effects:
     * - Updates the `feeAddress` state variable.
     *
     * @notice Emits:
     * - `FeeAddressUpdated` event indicating successful setting of the global fee address.
     *
     * @param _val The new fee address.
     */
    function setFeeAddress(
        address _val
    ) external override onlyOwner validAddress(_val) {
        require(feeAddress != _val, "3017");
        emit FeeAddressUpdated(feeAddress, _val);
        feeAddress = _val;
    }

    /**
     * @notice Sets the receipt token factory's address.
     *
     * @notice Requirements:
     * - `_val` must be different from previous `receiptTokenFactory` address.
     *
     * @notice Effects:
     * - Updates the `receiptTokenFactory` state variable.
     *
     * @notice Emits:
     * - `ReceiptTokenFactoryUpdated` event indicating successful setting of the `receiptTokenFactory` address.
     *
     * @param _factory Receipt token factory's address.
     */
    function setReceiptTokenFactory(
        address _factory
    ) external override onlyOwner validAddress(_factory) {
        require(receiptTokenFactory != _factory, "3017");
        emit ReceiptTokenFactoryUpdated(receiptTokenFactory, _factory);
        receiptTokenFactory = _factory;
    }

    /**
     * @notice Registers jUSD's oracle change request.
     *
     * @notice Requirements:
     * - Contract must not be in active change.
     *
     * @notice Effects:
     * - Updates the the `_isActiveChange` state variable.
     * - Updates the the `_newOracle` state variable.
     * - Updates the the `_newOracleTimestamp` state variable.
     *
     * @notice Emits:
     * - `NewOracleRequested` event indicating successful jUSD's oracle change request.
     *
     * @param _oracle Liquidity gauge factory's address.
     */
    function requestNewJUsdOracle(
        address _oracle
    ) external override onlyOwner {
        require(!_isActiveChange, "1000");
        _isActiveChange = true;
        _newOracle = _oracle;
        _newOracleTimestamp = block.timestamp;
        emit NewOracleRequested(_oracle);
    }

    /**
     * @notice Updates jUSD's oracle.
     *
     * @notice Requirements:
     * - Contract must be in active change.
     * - Timelock must expire.
     *
     * @notice Effects:
     * - Updates the the `jUsdOracle` state variable.
     * - Updates the the `_isActiveChange` state variable.
     * - Updates the the `_newOracle` state variable.
     * - Updates the the `_newOracleTimestamp` state variable.
     *
     * @notice Emits:
     * - `OracleUpdated` event indicating successful jUSD's oracle change.
     */
    function setJUsdOracle() external override onlyOwner {
        require(_isActiveChange, "1000");
        require(_newOracleTimestamp + timelockAmount <= block.timestamp, "3066");
        emit OracleUpdated(address(jUsdOracle), _newOracle);
        jUsdOracle = IOracle(_newOracle);
        _isActiveChange = false;
        _newOracle = address(0);
        _newOracleTimestamp = 0;
    }

    /**
     * @notice Updates the jUSD's oracle data.
     *
     * @notice Requirements:
     * - `_newOracleData` must be different from previous `oracleData`.
     *
     * @notice Effects:
     * - Updates the `oracleData` state variable.
     *
     * @notice Emits:
     * - `OracleDataUpdated` event indicating successful update of the oracle Data.
     *
     * @param _newOracleData New data used for jUSD's oracle data.
     */
    function setJUsdOracleData(
        bytes calldata _newOracleData
    ) external override onlyOwner {
        require(keccak256(oracleData) != keccak256(_newOracleData), "3017");
        emit OracleDataUpdated(oracleData, _newOracleData);
        oracleData = _newOracleData;
    }

    /**
     * @notice Registers timelock change request.
     *
     * @notice Requirements:
     * - Contract must not be in active change.
     * - `_oldTimelock` must be set zero.
     * - `_newVal` must be greater than zero.
     *
     * @notice Effects:
     * - Updates the the `_isActiveChange` state variable.
     * - Updates the the `_oldTimelock` state variable.
     * - Updates the the `_newTimelock` state variable.
     * - Updates the the `_newTimelockTimestamp` state variable.
     *
     * @notice Emits:
     * - `TimelockAmountUpdateRequested` event indicating successful timelock change request.
     *
     * @param _newVal The new timelock value in seconds.
     */
    function requestTimelockAmountChange(
        uint256 _newVal
    ) external override onlyOwner {
        require(!_isActiveChange, "1000");
        require(_oldTimelock == 0, "2100");
        require(_newVal != 0, "2001");
        _isActiveChange = true;
        _oldTimelock = timelockAmount;
        _newTimelock = _newVal;
        _newTimelockTimestamp = block.timestamp;
        emit TimelockAmountUpdateRequested(_oldTimelock, _newTimelock);
    }

    /**
     * @notice Updates the timelock amount.
     *
     * @notice Requirements:
     * - Contract must be in active change.
     * - `_newTimelock` must be greater than zero.
     * - The old timelock must expire.
     *
     * @notice Effects:
     * - Updates the the `timelockAmount` state variable.
     * - Updates the the `_oldTimelock` state variable.
     * - Updates the the `_newTimelock` state variable.
     * - Updates the the `_newTimelockTimestamp` state variable.
     *
     * @notice Emits:
     * - `TimelockAmountUpdated` event indicating successful timelock amount change.
     */
    function acceptTimelockAmountChange() external override onlyOwner {
        require(_isActiveChange, "1000");
        require(_newTimelock != 0, "2001");
        require(_newTimelockTimestamp + _oldTimelock <= block.timestamp, "3066");
        timelockAmount = _newTimelock;
        emit TimelockAmountUpdated(_oldTimelock, _newTimelock);
        _oldTimelock = 0;
        _newTimelock = 0;
        _newTimelockTimestamp = 0;
    }

    /**
     * @notice Override to avoid losing contract ownership.
     */
    function renounceOwnership() public pure override {
        revert("1000");
    }

    // -- Getters --

    /**
     * @notice Returns the up to date exchange rate of the protocol's stablecoin jUSD.
     *
     * @notice Requirements:
     * - Oracle must have updated rate.
     * - Rate must be a non zero positive value.
     *
     * @return The current exchange rate.
     */
    function getJUsdExchangeRate() external view override returns (uint256) {
        (bool updated, uint256 rate) = jUsdOracle.peek(oracleData);
        require(updated, "3037");
        require(rate > 0, "2100");
        return rate;
    }

    // Modifiers

    /**
     * @dev Modifier to check if the address is valid (not zero address).
     * @param _address being checked.
     */
    modifier validAddress(
        address _address
    ) {
        require(_address != address(0), "3000");
        _;
    }

    /**
     * @dev Modifier to check if the amount is valid (greater than zero).
     * @param _amount being checked.
     */
    modifier validAmount(
        uint256 _amount
    ) {
        require(_amount > 0, "2001");
        _;
    }
}
