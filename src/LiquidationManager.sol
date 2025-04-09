// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IHolding } from "./interfaces/core/IHolding.sol";
import { IHoldingManager } from "./interfaces/core/IHoldingManager.sol";
import { ILiquidationManager } from "./interfaces/core/ILiquidationManager.sol";
import { IManager } from "./interfaces/core/IManager.sol";

import { ISharesRegistry } from "./interfaces/core/ISharesRegistry.sol";
import { IStablesManager } from "./interfaces/core/IStablesManager.sol";
import { IStrategy } from "./interfaces/core/IStrategy.sol";
import { IStrategyManager } from "./interfaces/core/IStrategyManager.sol";
import { ISwapManager } from "./interfaces/core/ISwapManager.sol";

/**
 * @title LiquidationManager
 *
 * @notice Manages the liquidation and self-liquidation processes.
 *
 * @dev Self-liquidation enables solvent user to repay their stablecoin debt using their own collateral, freeing up
 * remaining collateral without attracting additional funds.
 * @dev Liquidation is a process initiated by a third party (liquidator) to liquidate  an insolvent user's
 * stablecoin debt. The liquidator uses their funds (stablecoin) in exchange for the user's collateral, plus a
 * liquidator's bonus.
 *
 * @dev This contract inherits functionalities from `Ownable2Step`, `Pausable`, `ReentrancyGuard.
 *
 * @author Hovooo (@hovooo), Cosmin Grigore (@gcosmintech).
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract LiquidationManager is ILiquidationManager, Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /**
     * @notice The self-liquidation fee.
     * @dev Uses 3 decimal precision, where 1% is represented as 1000.
     * @dev 8% is the default self-liquidation fee.
     */
    uint256 public override selfLiquidationFee = 8e3;

    /**
     * @notice The max % amount the protocol gets when a self-liquidation operation happens.
     * @dev Uses 3 decimal precision, where 1% is represented as 1000.
     * @dev 10% is the max self-liquidation fee.
     */
    uint256 public constant override MAX_SELF_LIQUIDATION_FEE = 10e3;

    /**
     * @notice utility variable used for preciser computations.
     */
    uint256 public constant override LIQUIDATION_PRECISION = 1e5;

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     */
    IManager public override manager;

    // -- Constructor --

    /**
     * @notice Creates a new LiquidationManager contract.
     * @param _initialOwner The initial owner of the contract.
     * @param _manager Contract that holds all the necessary configs of the protocol.
     */
    constructor(address _initialOwner, address _manager) Ownable(_initialOwner) {
        require(_manager != address(0), "3065");
        manager = IManager(_manager);
    }

    // -- User specific methods --

    /**
     * @notice This function allows a user to self-liquidate by repaying their jUSD debt using their own collateral. The
     * function ensures the user is solvent, calculates the required collateral, handles collateral retrieval from
     * strategies if needed, and performs the necessary swaps and transfers.
     *
     * @notice Requirements:
     * - `msg.sender` must have holding.
     * - `msg.sender` must be solvent.
     * - There should be enough liquidity in jUSD pool.
     * - `_jUsdAmount` must be <= user's borrowed amount.
     *
     * @notice Effects:
     * - Retrieves collateral from specified strategies if needed.
     * - Swaps user's collateral to required `_jUsdAmount`.
     * - Sends fees to `feeAddress`.
     * - Repays user's debt in the amount of `jUsdAmountRepaid`.
     * - Removes used `collateralUsed` from `holding`.
     *
     * @notice Emits:
     * - `SelfLiquidated` event indicating self-liquidation.
     *
     * @param _collateral address of the token used as collateral for borrowing.
     * @param _jUsdAmount to repay.
     * @param _swapParams used for the swap operation: swap path, maximum input amount, and slippage percentage.
     * @param _strategiesParams data for strategies to retrieve collateral from.
     *
     * @return collateralUsed for self-liquidation.
     * @return jUsdAmountRepaid amount repaid.
     */
    function selfLiquidate(
        address _collateral,
        uint256 _jUsdAmount,
        SwapParamsCalldata calldata _swapParams,
        StrategiesParamsCalldata calldata _strategiesParams
    )
        external
        override
        nonReentrant
        whenNotPaused
        validAddress(_collateral)
        validAmount(_jUsdAmount)
        returns (uint256 collateralUsed, uint256 jUsdAmountRepaid)
    {
        // Initialize self-liquidation temporary data struct.
        SelfLiquidateTempData memory tempData = SelfLiquidateTempData({
            holdingManager: _getHoldingManager(),
            stablesManager: _getStablesManager(),
            swapManager: _getSwapManager(),
            holding: address(0),
            isRegistryActive: false,
            registryAddress: address(0),
            totalBorrowed: 0,
            totalAvailableCollateral: 0,
            totalRequiredCollateral: 0,
            totalSelfLiquidatableCollateral: 0,
            totalFeeCollateral: 0,
            jUsdAmountToBurn: 0,
            exchangeRate: 0,
            collateralInStrategies: 0,
            swapPath: _swapParams.swapPath,
            deadline: _swapParams.deadline,
            amountInMaximum: _swapParams.amountInMaximum,
            slippagePercentage: _swapParams.slippagePercentage,
            useHoldingBalance: _strategiesParams.useHoldingBalance,
            strategies: _strategiesParams.strategies,
            strategiesData: _strategiesParams.strategiesData
        });

        // Get precision for computations.
        uint256 precision = LIQUIDATION_PRECISION;

        // Get user's holding.
        tempData.holding = tempData.holdingManager.userHolding(msg.sender);

        // Ensure that user has a holding account in the system.
        require(tempData.holdingManager.isHolding(tempData.holding), "3002");

        // Ensure collateral registry is active.
        (tempData.isRegistryActive, tempData.registryAddress) = tempData.stablesManager.shareRegistryInfo(_collateral);
        require(tempData.isRegistryActive, "1200");

        // Ensure user is solvent.
        tempData.totalBorrowed = ISharesRegistry(tempData.registryAddress).borrowed(tempData.holding);
        require(tempData.stablesManager.isSolvent({ _token: _collateral, _holding: tempData.holding }), "3075");

        // Ensure self-liquidation amount <= borrowed.
        tempData.jUsdAmountToBurn = _jUsdAmount;
        require(tempData.jUsdAmountToBurn <= tempData.totalBorrowed, "2003");

        // Calculate the collateral required for self-liquidation.
        tempData.exchangeRate = ISharesRegistry(tempData.registryAddress).getExchangeRate();
        tempData.totalRequiredCollateral =
            _getCollateralForJUsd(_collateral, tempData.jUsdAmountToBurn, tempData.exchangeRate);

        // Ensure that amountInMaximum is within acceptable range specified by user.
        // See the interface for specs on `slippagePercentage`.

        // Ensure safe computation.
        require(_swapParams.slippagePercentage <= precision, "3081");
        if (
            tempData.amountInMaximum
                > tempData.totalRequiredCollateral
                    + tempData.totalRequiredCollateral.mulDiv(_swapParams.slippagePercentage, precision)
        ) {
            revert("3078");
        }

        // Calculate the self-liquidation fee amount.
        tempData.totalFeeCollateral = tempData.amountInMaximum.mulDiv(selfLiquidationFee, precision, Math.Rounding.Ceil);
        // Calculate the total self-liquidatable collateral required to perform self-liquidation.
        tempData.totalSelfLiquidatableCollateral = tempData.amountInMaximum + tempData.totalFeeCollateral;

        // Retrieve collateral from strategies if needed.
        if (tempData.strategies.length > 0) {
            tempData.collateralInStrategies = _retrieveCollateral({
                _token: _collateral,
                _holding: tempData.holding,
                _amount: tempData.totalSelfLiquidatableCollateral,
                _strategies: tempData.strategies,
                _strategiesData: tempData.strategiesData,
                useHoldingBalance: tempData.useHoldingBalance
            });
        }

        // Set totalAvailableCollateral equal to retrieved collateral or holding's balance as user's specified.
        tempData.totalAvailableCollateral = !tempData.useHoldingBalance
            ? tempData.collateralInStrategies
            : IERC20Metadata(_collateral).balanceOf(tempData.holding);

        // Ensure there's enough available collateral to execute self-liquidation with specified amounts.
        require(tempData.totalAvailableCollateral >= tempData.totalSelfLiquidatableCollateral, "3076");

        // Swap collateral for jUSD.
        uint256 collateralUsedForSwap = tempData.swapManager.swapExactOutputMultihop({
            _tokenIn: _collateral,
            _swapPath: tempData.swapPath,
            _userHolding: tempData.holding,
            _deadline: tempData.deadline,
            _amountOut: tempData.jUsdAmountToBurn,
            _amountInMaximum: tempData.amountInMaximum
        });

        // Compute the final fee amount (if any) to be paid for performing self-liquidation.
        uint256 finalFeeCollateral = collateralUsedForSwap.mulDiv(selfLiquidationFee, precision, Math.Rounding.Ceil);

        // Transfer fees to fee address.
        if (finalFeeCollateral != 0) {
            IHolding(tempData.holding).transfer({
                _token: _collateral,
                _to: manager.feeAddress(),
                _amount: finalFeeCollateral
            });
        }

        // Save the jUSD amount that has been repaid.
        jUsdAmountRepaid = tempData.jUsdAmountToBurn;
        // Save the amount of collateral that has been used to repay jUSD.
        collateralUsed = collateralUsedForSwap + finalFeeCollateral;

        // Repay debt with jUsd obtained from Uniswap.
        tempData.stablesManager.repay({
            _holding: tempData.holding,
            _token: _collateral,
            _amount: jUsdAmountRepaid,
            _burnFrom: tempData.holding
        });

        // Remove collateral from holding.
        tempData.stablesManager.removeCollateral({
            _holding: tempData.holding,
            _token: _collateral,
            _amount: collateralUsed
        });

        // Emit event indicating self-liquidation.
        emit SelfLiquidated({
            holding: tempData.holding,
            token: _collateral,
            amount: jUsdAmountRepaid,
            collateralUsed: collateralUsed
        });
    }

    /**
     * @notice Method used to liquidate stablecoin debt if a user is no longer solvent.
     *
     * @notice Requirements:
     * - `_user` must have holding.
     * - `_user` must be insolvent.
     * - `msg.sender` must have jUSD.
     * - `_jUsdAmount` must be <= user's borrowed amount
     *
     * @notice Effects:
     * - Retrieves collateral from specified strategies if needed.
     * - Sends the liquidator their bonus and underlying collateral.
     * - Repays user's debt in the amount of `_jUsdAmount`.
     * - Removes used `collateralUsed` from `holding`.
     *
     * @notice Emits:
     * - `Liquidated` event indicating liquidation.
     *
     * @param _user address whose holding is to be liquidated.
     * @param _collateral token used for borrowing.
     * @param _jUsdAmount to repay.
     * @param _minCollateralReceive amount of collateral the liquidator wants to get.
     * @param _data for strategies to retrieve collateral from in case the Holding balance is not enough.
     *
     * @return collateralUsed The amount of collateral used for liquidation.
     */
    function liquidate(
        address _user,
        address _collateral,
        uint256 _jUsdAmount,
        uint256 _minCollateralReceive,
        LiquidateCalldata calldata _data
    )
        external
        override
        nonReentrant
        whenNotPaused
        validAddress(_collateral)
        validAmount(_jUsdAmount)
        returns (uint256 collateralUsed)
    {
        // Get protocol's required contracts to interact with.
        IHoldingManager holdingManager = _getHoldingManager();
        IStablesManager stablesManager = _getStablesManager();

        // Get address of the user's Holding involved in liquidation.
        address holding = holdingManager.userHolding(_user);
        // Get configs for collateral used for liquidation.
        (bool isRegistryActive, address registryAddress) = stablesManager.shareRegistryInfo(_collateral);

        // Perform sanity checks.
        require(isRegistryActive, "1200");
        require(holdingManager.isHolding(holding), "3002");
        require(_jUsdAmount <= ISharesRegistry(registryAddress).borrowed(holding), "2003");
        require(stablesManager.isLiquidatable({ _token: _collateral, _holding: holding }), "3073");

        // Calculate collateral required for the specified `_jUsdAmount`.
        collateralUsed = _getCollateralForJUsd({
            _collateral: _collateral,
            _jUsdAmount: _jUsdAmount,
            _exchangeRate: ISharesRegistry(registryAddress).getExchangeRate()
        });

        // Update the required collateral amount if there's liquidator bonus.
        collateralUsed += _user == msg.sender
            ? 0
            : collateralUsed.mulDiv(
                ISharesRegistry(registryAddress).getConfig().liquidatorBonus, LIQUIDATION_PRECISION, Math.Rounding.Ceil
            );

        // If strategies are provided, retrieve collateral from strategies if needed.
        if (_data.strategies.length > 0) {
            _retrieveCollateral({
                _token: _collateral,
                _holding: holding,
                _amount: collateralUsed,
                _strategies: _data.strategies,
                _strategiesData: _data.strategiesData,
                useHoldingBalance: true
            });
        }

        // Check whether the holding actually has enough collateral to pay liquidator bonus.
        collateralUsed = Math.min(IERC20(_collateral).balanceOf(holding), collateralUsed);

        // Ensure the liquidator will receive at least as much collateral as expected when sending the tx.
        require(collateralUsed >= _minCollateralReceive, "3097");

        // Emit event indicating successful liquidation.
        emit Liquidated({ holding: holding, token: _collateral, amount: _jUsdAmount, collateralUsed: collateralUsed });

        // Repay user's debt with jUSD owned by the liquidator.
        stablesManager.repay({ _holding: holding, _token: _collateral, _amount: _jUsdAmount, _burnFrom: msg.sender });
        // Remove collateral from holding.
        stablesManager.forceRemoveCollateral({ _holding: holding, _token: _collateral, _amount: collateralUsed });
        // Send the liquidator the freed up collateral and bonus.
        IHolding(holding).transfer({ _token: _collateral, _to: msg.sender, _amount: collateralUsed });
    }

    /**
     * @notice Method used to liquidate positions with bad debt (where collateral value is less than borrowed amount).
     *
     * @notice Requirements:
     * - Only owner can call this function.
     * - `_user` must have holding.
     * - Holding must have bad debt (collateral value < borrowed amount).
     * - All strategies associated with the holding must be provided.
     *
     * @notice Effects:
     * - Retrieves collateral from specified strategies.
     * - Repays user's total debt with jUSD from msg.sender.
     * - Removes all remaining collateral from holding.
     * - Transfers all remaining collateral to msg.sender.
     *
     * @notice Emits:
     * - `CollateralRetrieved` event for each strategy collateral is retrieved from.
     *
     * @param _user Address whose holding is to be liquidated.
     * @param _collateral Token used for borrowing.
     * @param _data Struct containing arrays of strategies and their associated data for retrieving collateral.
     */
    function liquidateBadDebt(
        address _user,
        address _collateral,
        LiquidateCalldata calldata _data
    ) external override nonReentrant whenNotPaused onlyOwner validAddress(_collateral) {
        // Get protocol's required contracts to interact with.
        IHoldingManager holdingManager = _getHoldingManager();
        IStablesManager stablesManager = _getStablesManager();

        // Get address of the user's Holding involved in liquidation.
        address holding = holdingManager.userHolding(_user);
        // Get configs for collateral used for liquidation.
        (bool isRegistryActive, address registryAddress) = stablesManager.shareRegistryInfo(_collateral);

        // Perform sanity checks.
        require(isRegistryActive, "1200");
        require(holdingManager.isHolding(holding), "3002");

        uint256 totalBorrowed = ISharesRegistry(registryAddress).borrowed(holding);
        uint256 totalCollateral = ISharesRegistry(registryAddress).collateral(holding);

        // If strategies are provided, retrieve collateral from strategies if needed.
        if (_data.strategies.length > 0) {
            _retrieveCollateral({
                _token: _collateral,
                _holding: holding,
                _amount: totalCollateral,
                _strategies: _data.strategies,
                _strategiesData: _data.strategiesData,
                useHoldingBalance: true
            });
        }
        // Update total collateral after retrieving from strategies
        totalCollateral = ISharesRegistry(registryAddress).collateral(holding);

        // Verify holding has bad debt
        if (
            totalCollateral
                >= _getCollateralForJUsd({
                    _collateral: _collateral,
                    _jUsdAmount: totalBorrowed,
                    _exchangeRate: ISharesRegistry(registryAddress).getExchangeRate()
                })
        ) revert("3099");

        // Emit event indicating successful liquidation of bad debt .
        emit BadDebtLiquidated({
            holding: holding,
            token: _collateral,
            amount: totalBorrowed,
            collateralUsed: totalCollateral
        });

        // Repay user's debt with jUSD
        stablesManager.repay({ _holding: holding, _token: _collateral, _amount: totalBorrowed, _burnFrom: msg.sender });
        // Remove collateral from holding.
        stablesManager.forceRemoveCollateral({ _holding: holding, _token: _collateral, _amount: totalCollateral });
        // Send the liquidator the freed up collateral and bonus.
        IHolding(holding).transfer({ _token: _collateral, _to: msg.sender, _amount: totalCollateral });
    }

    // -- Administration --

    /**
     * @notice Sets a new value for the self-liquidation fee.
     * @dev The value must be less than MAX_SELF_LIQUIDATION_FEE.
     * @param _val The new value for the self-liquidation fee.
     */
    function setSelfLiquidationFee(
        uint256 _val
    ) external override onlyOwner {
        require(_val <= MAX_SELF_LIQUIDATION_FEE, "3066");
        emit SelfLiquidationFeeUpdated(selfLiquidationFee, _val);
        selfLiquidationFee = _val;
    }

    /**
     * @notice Triggers stopped state.
     */
    function pause() external override onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @notice Returns to normal state.
     */
    function unpause() external override onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @notice Renounce ownership override to avoid losing contract's ownership.
     */
    function renounceOwnership() public pure override {
        revert("1000");
    }

    // -- Private methods --

    /**
     * @notice This function calculates the amount of collateral needed to match a given jUSD amount based on the
     * provided exchange rate.
     *
     * @param _collateral address of the collateral token.
     * @param _jUsdAmount amount of jUSD.
     * @param _exchangeRate collateral to jUSD.
     *
     * @return totalCollateral The total amount of collateral required.
     */
    function _getCollateralForJUsd(
        address _collateral,
        uint256 _jUsdAmount,
        uint256 _exchangeRate
    ) private view returns (uint256 totalCollateral) {
        uint256 EXCHANGE_RATE_PRECISION = manager.EXCHANGE_RATE_PRECISION();
        // Calculate collateral amount based on its USD value.
        totalCollateral = _jUsdAmount.mulDiv(EXCHANGE_RATE_PRECISION, _exchangeRate, Math.Rounding.Ceil);

        // Adjust collateral amount in accordance with current jUSD price.
        totalCollateral =
            totalCollateral.mulDiv(manager.getJUsdExchangeRate(), EXCHANGE_RATE_PRECISION, Math.Rounding.Ceil);

        // Perform sanity check to avoid miscalculations.
        require(totalCollateral > 0, "3079");

        // Transform from 18 decimals to collateral's decimals
        uint256 collateralDecimals = IERC20Metadata(_collateral).decimals();
        if (collateralDecimals > 18) totalCollateral = totalCollateral * (10 ** (collateralDecimals - 18));
        else if (collateralDecimals < 18) totalCollateral = totalCollateral.ceilDiv(10 ** (18 - collateralDecimals));
    }

    /**
     * @notice Method used to force withdraw from strategies. If `useHoldingBalance` is set to true
     * and the holding has enough balance, strategies are ignored.
     *
     * @param _token address to retrieve.
     * @param _holding address from which to retrieve collateral.
     * @param _amount of collateral to retrieve.
     * @param _strategies array from which to retrieve collateral.
     * @param _strategiesData array of data associated with each strategy.
     * @param useHoldingBalance boolean indicating whether to use the holding balance.
     *
     * @return The amount of collateral retrieved.
     */
    function _retrieveCollateral(
        address _token,
        address _holding,
        uint256 _amount,
        address[] memory _strategies,
        bytes[] memory _strategiesData,
        bool useHoldingBalance
    ) private returns (uint256) {
        CollateralRetrievalData memory tempData =
            CollateralRetrievalData({ retrievedCollateral: 0, shares: 0, withdrawResult: 0 });

        // Ensure the holding doesn't already have enough collateral.
        if (useHoldingBalance) if (IERC20(_token).balanceOf(_holding) >= _amount) return _amount;

        // Ensure that extra data for strategies is provided correctly.
        require(_strategies.length == _strategiesData.length, "3026");

        // Iterate over sent strategies and retrieve collateral.
        for (uint256 i = 0; i < _strategies.length; i++) {
            (, tempData.shares) = IStrategy(_strategies[i]).recipients(_holding);

            // Withdraw collateral.
            (tempData.withdrawResult,,,) = _getStrategyManager().claimInvestment({
                _holding: _holding,
                _token: _token,
                _strategy: _strategies[i],
                _shares: tempData.shares,
                _data: _strategiesData[i]
            });

            // Update amount of retrieved collateral.
            tempData.retrievedCollateral += tempData.withdrawResult;

            // Emit event indicating collateral retrieval.
            emit CollateralRetrieved(_token, _holding, _strategies[i], tempData.withdrawResult);

            // Continue withdrawing from strategies only if the required amount has not been reached yet
            if (useHoldingBalance && IERC20(_token).balanceOf(_holding) >= _amount) break;
        }

        // Return the amount of retrieved collateral.
        return tempData.retrievedCollateral;
    }

    /**
     * @notice Utility function do get available StablesManager Contract.
     */
    function _getStablesManager() private view returns (IStablesManager) {
        return IStablesManager(manager.stablesManager());
    }

    /**
     * @notice Utility function do get available HoldingManager Contract.
     */
    function _getHoldingManager() private view returns (IHoldingManager) {
        return IHoldingManager(manager.holdingManager());
    }

    /**
     * @notice Utility function do get available SwapManager Contract.
     */
    function _getSwapManager() private view returns (ISwapManager) {
        return ISwapManager(manager.swapManager());
    }

    /**
     * @notice Utility function do get available StrategyManager Contract.
     */
    function _getStrategyManager() private view returns (IStrategyManager) {
        return IStrategyManager(manager.strategyManager());
    }

    // -- Modifiers --

    /**
     * @notice Modifier to ensure that the provided address is valid (not the zero address).
     * @param _address The address to validate
     */
    modifier validAddress(
        address _address
    ) {
        require(_address != address(0), "3000");
        _;
    }

    /**
     * @notice Modifier to ensure that the provided amount is valid (greater than zero).
     * @param _amount The amount to validate
     */
    modifier validAmount(
        uint256 _amount
    ) {
        require(_amount > 0, "2001");
        _;
    }
}
