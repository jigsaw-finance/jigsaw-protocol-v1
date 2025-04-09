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
    mapping(address token => bool withdrawable) public override isTokenWithdrawable;

    /**
     * @notice Returns true if caller is allowed invoker.
     */
    mapping(address invoker => bool allowed) public override allowedInvokers;

    // -- Essential tokens --

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
     * @notice Returns the maximum performance fee.
     * @dev Uses 2 decimal precision, where 1% is represented as 100.
     */
    uint256 public immutable override MAX_PERFORMANCE_FEE = 2500; //25%

    /**
     * @notice Fee for withdrawing from a holding.
     * @dev Uses 2 decimal precision, where 1% is represented as 100.
     */
    uint256 public override withdrawalFee;

    /**
     * @notice Returns the maximum withdrawal fee.
     * @dev Uses 2 decimal precision, where 1% is represented as 100.
     */
    uint256 public immutable override MAX_WITHDRAWAL_FEE = 800; //8%

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
     * @notice Minimum allowed jUSD debt amount for a holding to ensure successful liquidation.
     * @dev 200 jUSD is the initial minimum allowed debt amount for a holding to ensure successful liquidation.
     */
    uint256 public override minDebtAmount = 200e18;

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
    uint256 public override oldTimelock;
    uint256 public override newTimelock;
    uint256 public override newTimelockTimestamp;

    /**
     * @notice Variables required for delayed oracle update.
     */
    address public override newOracle;
    uint256 public override newOracleTimestamp;

    /**
     * @notice Variables required for delayed swap manager update.
     */
    address public override newSwapManager;
    uint256 public override newSwapManagerTimestamp;

    /**
     * @notice Variables required for delayed liquidation manager update.
     */
    address public override newLiquidationManager;
    uint256 public override newLiquidationManagerTimestamp;

    /**
     * @notice Creates a new Manager Contract.
     *
     * @param _initialOwner The initial owner of the contract.
     * @param _weth The WETH address.
     * @param _oracle The jUSD oracle address.
     * @param _oracleData The jUSD initial oracle data.
     */
    constructor(
        address _initialOwner,
        address _weth,
        address _oracle,
        bytes memory _oracleData
    ) Ownable(_initialOwner) validAddress(_weth) validAddress(_oracle) {
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
     * @notice Registers the `_token` as withdrawable.
     *
     * @notice Requirements:
     * - `msg.sender` must be owner or `stablesManager`.
     * - `_token` must not be withdrawable.
     *
     * @notice Effects:
     * - Updates the `isTokenWithdrawable` mapping.
     *
     * @notice Emits:
     * - `WithdrawableTokenAdded` event indicating successful withdrawable token addition operation.
     *
     * @param _token The address of the token to be added as withdrawable.
     */
    function addWithdrawableToken(
        address _token
    ) external override validAddress(_token) {
        require(owner() == msg.sender || stablesManager == msg.sender, "1000");
        require(!isTokenWithdrawable[_token], "3069");
        isTokenWithdrawable[_token] = true;
        emit WithdrawableTokenAdded(_token);
    }

    /**
     * @notice Unregisters the `_token` as withdrawable.
     *
     * @notice Requirements:
     * - `_token` must be withdrawable.
     *
     * @notice Effects:
     * - Updates the `isTokenWithdrawable` mapping.
     *
     * @notice Emits:
     * - `WithdrawableTokenRemoved` event indicating successful withdrawable token removal operation.
     *
     * @param _token The address of the token to be removed as withdrawable.
     */
    function removeWithdrawableToken(
        address _token
    ) external override onlyOwner validAddress(_token) {
        require(isTokenWithdrawable[_token], "3070");
        isTokenWithdrawable[_token] = false;
        emit WithdrawableTokenRemoved(_token);
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
     * - Can only be called once.
     * - `_val` must be non-zero address.
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
        require(holdingManager == address(0), "3017");
        emit HoldingManagerUpdated(holdingManager, _val);
        holdingManager = _val;
    }

    /**
     * @notice Sets the Liquidation Manager Contract's address.
     *
     * @notice Requirements:
     * - Can only be called once.
     * - `_val` must be non-zero address.
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
        require(liquidationManager == address(0), "3017");
        emit LiquidationManagerUpdated(liquidationManager, _val);
        liquidationManager = _val;
    }

    /**
     * @notice Initiates the process to update the Liquidation Manager Contract's address.
     *
     * @notice Requirements:
     * - `_val` must be non-zero address.
     * - `_val` must be different from previous `liquidationManager` address.
     *
     * @notice Effects:
     * - Updates the the `newLiquidationManager` state variable.
     * - Updates the the `newLiquidationManagerTimestamp` state variable.
     *
     * @notice Emits:
     * - `LiquidationManagerUpdateRequested` event indicating successful liquidation manager change request.
     *
     * @param _val The new liquidation manager's address.
     */
    function requestNewLiquidationManager(
        address _val
    ) external override onlyOwner validAddress(_val) {
        require(liquidationManager != _val, "3017");

        emit NewLiquidationManagerRequested(liquidationManager, _val);

        newLiquidationManager = _val;
        newLiquidationManagerTimestamp = block.timestamp;
    }

    /**
     * @notice Sets the Liquidation Manager Contract's address.
     *
     * @notice Requirements:
     * - `_val` must be different from previous `liquidationManager` address.
     * - Timelock must expire.
     *
     * @notice Effects:
     * - Updates the `liquidationManager` state variable.
     * - Updates the the `newLiquidationManager` state variable.
     * - Updates the the `newLiquidationManagerTimestamp` state variable.
     *
     * @notice Emits:
     * - `LiquidationManagerUpdated` event indicating the successful setting of the Liquidation Manager's address.
     */
    function acceptNewLiquidationManager() external override onlyOwner {
        require(newLiquidationManager != address(0), "3063");
        require(newLiquidationManagerTimestamp + timelockAmount <= block.timestamp, "3066");

        emit LiquidationManagerUpdated(liquidationManager, newLiquidationManager);

        liquidationManager = newLiquidationManager;
        newLiquidationManager = address(0);
        newLiquidationManagerTimestamp = 0;
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
        require(stablesManager == address(0), "3017");
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
        require(strategyManager == address(0), "3017");
        emit StrategyManagerUpdated(strategyManager, _val);
        strategyManager = _val;
    }

    /**
     * @notice Sets the Swap Manager Contract's address.
     *
     * @notice Requirements:
     * - Can only be called once.
     * - `_val` must be non-zero address.
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
        require(swapManager == address(0), "3017");
        emit SwapManagerUpdated(swapManager, _val);
        swapManager = _val;
    }

    /**
     * @notice Initiates the process to update the Swap Manager Contract's address.
     *
     * @notice Requirements:
     * - `_val` must be non-zero address.
     * - `_val` must be different from previous `swapManager` address.
     *
     * @notice Effects:
     * - Updates the the `newSwapManager` state variable.
     * - Updates the the `newSwapManagerTimestamp` state variable.
     *
     * @notice Emits:
     * - `NewSwapManagerRequested` event indicating successful swap manager change request.
     *
     * @param _val The new swap manager's address.
     */
    function requestNewSwapManager(
        address _val
    ) external override onlyOwner validAddress(_val) {
        require(swapManager != _val, "3017");

        emit NewSwapManagerRequested(swapManager, _val);

        newSwapManager = _val;
        newSwapManagerTimestamp = block.timestamp;
    }

    /**
     * @notice Updates the Swap Manager Contract    .
     *
     * @notice Requirements:
     * - Timelock must expire.
     *
     * @notice Effects:
     * - Updates the `swapManager` state variable.
     * - Resets `newSwapManager` to address(0).
     * - Resets `newSwapManagerTimestamp` to 0.
     *
     * @notice Emits:
     * - `SwapManagerUpdated` event indicating the successful setting of the Swap Manager's address.
     */
    function acceptNewSwapManager() external override onlyOwner {
        require(newSwapManager != address(0), "3063");
        require(newSwapManagerTimestamp + timelockAmount <= block.timestamp, "3066");

        emit SwapManagerUpdated(swapManager, newSwapManager);

        swapManager = newSwapManager;
        newSwapManager = address(0);
        newSwapManagerTimestamp = 0;
    }

    /**
     * @notice Sets the performance fee.
     *
     * @notice Requirements:
     * - `_val` must be smaller than `MAX_PERFORMANCE_FEE`.
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
    ) external override onlyOwner {
        require(performanceFee != _val, "3017");
        require(_val < MAX_PERFORMANCE_FEE, "3018");
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
        require(_val <= MAX_WITHDRAWAL_FEE, "3018");
        emit WithdrawalFeeUpdated(withdrawalFee, _val);
        withdrawalFee = _val;
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
     * - Updates the the `newOracle` state variable.
     * - Updates the the `newOracleTimestamp` state variable.
     *
     * @notice Emits:
     * - `NewOracleRequested` event indicating successful jUSD's oracle change request.
     *
     * @param _oracle Liquidity gauge factory's address.
     */
    function requestNewJUsdOracle(
        address _oracle
    ) external override onlyOwner validAddress(_oracle) {
        require(newOracle == address(0), "3017");
        require(address(jUsdOracle) != _oracle, "3017");

        emit NewOracleRequested(_oracle);

        newOracle = _oracle;
        newOracleTimestamp = block.timestamp;
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
     * - Updates the the `newOracle` state variable.
     * - Updates the the `newOracleTimestamp` state variable.
     *
     * @notice Emits:
     * - `OracleUpdated` event indicating successful jUSD's oracle change.
     */
    function acceptNewJUsdOracle() external override onlyOwner {
        require(newOracle != address(0), "3063");
        require(newOracleTimestamp + timelockAmount <= block.timestamp, "3066");

        emit OracleUpdated(address(jUsdOracle), newOracle);

        jUsdOracle = IOracle(newOracle);
        newOracle = address(0);
        newOracleTimestamp = 0;
    }

    /**
     * @notice Updates the jUSD's oracle data.
     *
     * @notice Requirements:
     * - `newOracleData` must be different from previous `oracleData`.
     *
     * @notice Effects:
     * - Updates the `oracleData` state variable.
     *
     * @notice Emits:
     * - `OracleDataUpdated` event indicating successful update of the oracle Data.
     *
     * @param newOracleData New data used for jUSD's oracle data.
     */
    function setJUsdOracleData(
        bytes calldata newOracleData
    ) external override onlyOwner {
        require(keccak256(oracleData) != keccak256(newOracleData), "3017");
        emit OracleDataUpdated(oracleData, newOracleData);
        oracleData = newOracleData;
    }

    /**
     * @notice Sets the minimum debt amount.
     *
     * @notice Requirements:
     * - `_minDebtAmount` must be greater than zero.
     * - `_minDebtAmount` must be different from previous `minDebtAmount`.
     *
     * @param _minDebtAmount The new minimum debt amount.
     */
    function setMinDebtAmount(
        uint256 _minDebtAmount
    ) external override onlyOwner {
        require(_minDebtAmount > 0, "2100");
        require(_minDebtAmount != minDebtAmount, "3017");
        minDebtAmount = _minDebtAmount;
    }

    /**
     * @notice Registers timelock change request.
     *
     * @notice Requirements:
     * - `oldTimelock` must be set zero.
     * - `newVal` must be greater than zero.
     *
     * @notice Effects:
     * - Updates the the `oldTimelock` state variable.
     * - Updates the the `newTimelock` state variable.
     * - Updates the the `newTimelockTimestamp` state variable.
     *
     * @notice Emits:
     * - `TimelockAmountUpdateRequested` event indicating successful timelock change request.
     *
     * @param newVal The new timelock value in seconds.
     */
    function requestNewTimelock(
        uint256 newVal
    ) external override onlyOwner {
        require(oldTimelock == 0, "3017");
        require(newVal != 0, "2001");

        newTimelock = newVal;
        oldTimelock = timelockAmount;

        emit TimelockAmountUpdateRequested(oldTimelock, newTimelock);

        newTimelockTimestamp = block.timestamp;
    }

    /**
     * @notice Updates the timelock amount.
     *
     * @notice Requirements:
     * - Contract must be in active change.
     * - `newTimelock` must be greater than zero.
     * - The old timelock must expire.
     *
     * @notice Effects:
     * - Updates the the `timelockAmount` state variable.
     * - Updates the the `oldTimelock` state variable.
     * - Updates the the `newTimelock` state variable.
     * - Updates the the `newTimelockTimestamp` state variable.
     *
     * @notice Emits:
     * - `TimelockAmountUpdated` event indicating successful timelock amount change.
     */
    function acceptNewTimelock() external override onlyOwner {
        require(newTimelock != 0, "2001");
        require(newTimelockTimestamp + oldTimelock <= block.timestamp, "3066");

        emit TimelockAmountUpdated(oldTimelock, newTimelock);

        timelockAmount = newTimelock;
        oldTimelock = 0;
        newTimelock = 0;
        newTimelockTimestamp = 0;
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
}
