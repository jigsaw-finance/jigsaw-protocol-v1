// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IOracle } from "../oracle/IOracle.sol";

/**
 * @title IManager.
 * @dev Interface for the Manager Contract.
 */
interface IManager {
    // -- Events --

    /**
     * @notice Emitted when a new contract is whitelisted.
     * @param contractAddress The address of the contract that is whitelisted.
     */
    event ContractWhitelisted(address indexed contractAddress);

    /**
     * @notice Emitted when a contract is removed from the whitelist.
     * @param contractAddress The address of the contract that is removed from the whitelist.
     */
    event ContractBlacklisted(address indexed contractAddress);

    /**
     * @notice Emitted when a new token is whitelisted.
     * @param token The address of the token that is whitelisted.
     */
    event TokenWhitelisted(address indexed token);

    /**
     * @notice Emitted when a new token is removed from the whitelist.
     * @param token The address of the token that is removed from the whitelist.
     */
    event TokenRemoved(address indexed token);

    /**
     * @notice Emitted when a non-withdrawable token is added.
     * @param token The address of the non-withdrawable token.
     */
    event NonWithdrawableTokenAdded(address indexed token);

    /**
     * @notice Emitted when a non-withdrawable token is removed.
     * @param token The address of the non-withdrawable token.
     */
    event NonWithdrawableTokenRemoved(address indexed token);

    /**
     * @notice Emitted when invoker is updated.
     * @param component The address of the invoker component.
     * @param allowed Boolean indicating if the invoker is allowed or not.
     */
    event InvokerUpdated(address indexed component, bool allowed);

    /**
     * @notice Emitted when the holding manager is set.
     * @param oldAddress The previous address of the holding manager.
     * @param newAddress The new address of the holding manager.
     */
    event HoldingManagerUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Emitted when the liquidation manager is set.
     * @param oldAddress The previous address of the liquidation manager.
     * @param newAddress The new address of the liquidation manager.
     */
    event LiquidationManagerUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Emitted when the stablecoin manager is set.
     * @param oldAddress The previous address of the stablecoin manager.
     * @param newAddress The new address of the stablecoin manager.
     */
    event StablecoinManagerUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Emitted when the strategy manager is set.
     * @param oldAddress The previous address of the strategy manager.
     * @param newAddress The new address of the strategy manager.
     */
    event StrategyManagerUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Emitted when the swap manager is set.
     * @param oldAddress The previous address of the swap manager.
     * @param newAddress The new address of the swap manager.
     */
    event SwapManagerUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Emitted when the default fee is updated.
     * @param oldFee The previous fee.
     * @param newFee The new fee.
     */
    event PerformanceFeeUpdated(uint256 indexed oldFee, uint256 indexed newFee);

    /**
     * @notice Emitted when the withdraw fee is updated.
     * @param oldFee The previous withdraw fee.
     * @param newFee The new withdraw fee.
     */
    event WithdrawalFeeUpdated(uint256 indexed oldFee, uint256 indexed newFee);

    /**
     * @notice Emitted when the liquidator's bonus is updated.
     * @param oldAmount The previous amount of the liquidator's bonus.
     * @param newAmount The new amount of the liquidator's bonus.
     */
    event LiquidatorBonusUpdated(uint256 oldAmount, uint256 newAmount);

    /**
     * @notice Emitted when the self-liquidation fee is updated.
     * @param oldAmount The previous amount of the self-liquidation fee.
     * @param newAmount The new amount of the self-liquidation fee.
     */
    event SelfLiquidationFeeUpdated(uint256 oldAmount, uint256 newAmount);

    /**
     * @notice Emitted when the fee address is changed.
     * @param oldAddress The previous fee address.
     * @param newAddress The new fee address.
     */
    event FeeAddressUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Emitted when the receipt token factory is updated.
     * @param oldAddress The previous address of the receipt token factory.
     * @param newAddress The new address of the receipt token factory.
     */
    event ReceiptTokenFactoryUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Emitted when the liquidity gauge factory is updated.
     * @param oldAddress The previous address of the liquidity gauge factory.
     * @param newAddress The new address of the liquidity gauge factory.
     */
    event LiquidityGaugeFactoryUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Emitted when new oracle is requested.
     * @param newOracle The address of the new oracle.
     */
    event NewOracleRequested(address newOracle);

    /**
     * @notice Emitted when the oracle is updated.
     * @param oldOracle The address of the old oracle.
     * @param newOracle The address of the new oracle.
     */
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    /**
     * @notice Emitted when oracle data is updated.
     * @param oldData The address of the old oracle data.
     * @param newData The address of the new oracle data.
     */
    event OracleDataUpdated(bytes indexed oldData, bytes indexed newData);

    /**
     * @notice Emitted when a new timelock amount is requested.
     * @param oldVal The previous timelock amount.
     * @param newVal The new timelock amount.
     */
    event TimelockAmountUpdateRequested(uint256 oldVal, uint256 newVal);

    /**
     * @notice Emitted when timelock amount is updated.
     * @param oldVal The previous timelock amount.
     * @param newVal The new timelock amount.
     */
    event TimelockAmountUpdated(uint256 oldVal, uint256 newVal);

    // -- Mappings --

    /**
     * @notice Returns true/false for contracts' whitelist status.
     * @param _contract The address of the contract.
     */
    function isContractWhitelisted(
        address _contract
    ) external view returns (bool);

    /**
     * @notice Returns true if token is whitelisted.
     * @param _token The address of the token.
     */
    function isTokenWhitelisted(
        address _token
    ) external view returns (bool);

    /**
     * @notice Returns true if the token cannot be withdrawn from a holding.
     * @param _token The address of the token.
     */
    function isTokenNonWithdrawable(
        address _token
    ) external view returns (bool);

    /**
     * @notice Returns true if caller is allowed invoker.
     * @param _invoker The address of the invoker.
     */
    function allowedInvokers(
        address _invoker
    ) external view returns (bool);

    // -- Essential tokens --

    /**
     * @notice USDC address.
     */
    function USDC() external view returns (address);

    /**
     * @notice WETH address.
     */
    function WETH() external view returns (address);

    // -- Protocol's stablecoin oracle config --

    /**
     * @notice Oracle contract associated with protocol's stablecoin.
     */
    function jUsdOracle() external view returns (IOracle);

    /**
     * @notice Extra oracle data if needed.
     */
    function oracleData() external view returns (bytes calldata);

    // -- Managers --

    /**
     * @notice Returns the address of the HoldingManager Contract.
     */
    function holdingManager() external view returns (address);

    /**
     * @notice Returns the address of the LiquidationManager Contract.
     */
    function liquidationManager() external view returns (address);

    /**
     * @notice Returns the address of the StablesManager Contract.
     */
    function stablesManager() external view returns (address);

    /**
     * @notice Returns the address of the StrategyManager Contract.
     */
    function strategyManager() external view returns (address);

    /**
     * @notice Returns the address of the SwapManager Contract.
     */
    function swapManager() external view returns (address);

    // -- Fees --

    /**
     * @notice Returns the default performance fee.
     * @dev Uses 2 decimal precision, where 1% is represented as 100.
     */
    function performanceFee() external view returns (uint256);

    /**
     * @notice Fee for withdrawing from a holding.
     * @dev Uses 2 decimal precision, where 1% is represented as 100.
     */
    function withdrawalFee() external view returns (uint256);

    /**
     * @notice The % amount a liquidator gets.
     * @dev Uses 3 decimal precision, where 1% is represented as 1000.
     * @dev 10% is the default liquidator's bonus.
     */
    function liquidatorBonus() external view returns (uint256);

    /**
     * @notice The max % amount the protocol gets when a self-liquidation operation happens.
     * @dev Uses 3 decimal precision, where 1% is represented as 1000.
     * @dev 8% is the default self-liquidation fee.
     */
    function selfLiquidationFee() external view returns (uint256);

    /**
     * @notice Returns the fee address, where all the fees are collected.
     */
    function feeAddress() external view returns (address);

    // -- Factories --

    /**
     * @notice Returns the address of the ReceiptTokenFactory.
     */
    function receiptTokenFactory() external view returns (address);

    // -- Utility values --

    /**
     * @notice Returns the collateral rate precision.
     * @dev Should be less than exchange rate precision due to optimization in math.
     */
    function PRECISION() external view returns (uint256);

    /**
     * @notice Returns the exchange rate precision.
     */
    function EXCHANGE_RATE_PRECISION() external view returns (uint256);

    /**
     * @notice Timelock amount in seconds for changing the oracle data.
     */
    function timelockAmount() external view returns (uint256);

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    function updateInvoker(address _component, bool _allowed) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    ) external;

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
    function setJUsdOracle() external;

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
    ) external;

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
    ) external;

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
    function acceptTimelockAmountChange() external;

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
    function getJUsdExchangeRate() external view returns (uint256);
}
