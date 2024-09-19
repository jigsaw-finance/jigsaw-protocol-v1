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
import { IManagerContainer } from "./interfaces/core/IManagerContainer.sol";

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
 * @dev Liquidation is a process is initiated by a third party (liquidator) to liquidate  an insolvent user's
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
     * @notice contract that contains the address of the Manager Container.
     */
    IManagerContainer public immutable override managerContainer;

    /**
     * @notice returns the liquidator's bonus amount.
     */
    uint256 public liquidatorBonus;

    /**
     * @notice returns the self-liquidation fee.
     */
    uint256 public selfLiquidationFee;

    /**
     * @notice utility variable used for preciser computations.
     */
    uint256 public constant LIQUIDATION_PRECISION = 1e5;

    // -- Constructor --

    /**
     * @notice Creates a new LiquidationManager contract.
     * @param _initialOwner The initial owner of the contract.
     * @param _managerContainer Contract that contains the address of the manager contract.
     */
    constructor(address _initialOwner, address _managerContainer) Ownable(_initialOwner) {
        require(_managerContainer != address(0), "3065");
        managerContainer = IManagerContainer(_managerContainer);
        liquidatorBonus = _getManager().liquidatorBonus();
        selfLiquidationFee = _getManager().selfLiquidationFee();
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

        // Ensure there are no potential rounding errors resulting from a small self-liquidation amount.
        require(tempData.totalRequiredCollateral > 0, "3080");

        // Calculate the self-liquidation fee amount.
        tempData.totalFeeCollateral =
            tempData.totalRequiredCollateral.mulDiv(selfLiquidationFee, precision, Math.Rounding.Ceil);

        // Calculate the total self-liquidatable collateral required to perform self-liquidation.
        tempData.totalSelfLiquidatableCollateral = tempData.totalRequiredCollateral + tempData.totalFeeCollateral;

        // Ensure that amountInMaximum is within acceptable range specified by user.
        // Set totalSelfLiquidatableCollateral equal to amountInMaximum if it is within acceptable range.
        // See the interface for specs on `slippagePercentage`.
        if (tempData.amountInMaximum > tempData.totalSelfLiquidatableCollateral) {
            // Ensure safe computation.
            require(_swapParams.slippagePercentage <= precision, "3081");
            if (
                tempData.amountInMaximum
                    <= tempData.totalSelfLiquidatableCollateral
                        + tempData.totalSelfLiquidatableCollateral.mulDiv(_swapParams.slippagePercentage, precision)
            ) {
                tempData.totalSelfLiquidatableCollateral = tempData.amountInMaximum;
            } else {
                // Revert if amountInMaximum is higher than allowed by user.
                revert("3078");
            }
        }

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
        tempData.totalAvailableCollateral = tempData.strategies.length > 0
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

        // Compute the remaining collateral.
        uint256 remainingCollateral = tempData.totalSelfLiquidatableCollateral - collateralUsedForSwap;
        // Compute the final fee amount (if any) to be paid for performing self-liquidation.
        uint256 finalFeeCollateral =
            remainingCollateral > tempData.totalFeeCollateral ? tempData.totalFeeCollateral : remainingCollateral;

        // Transfer fees to fee address.
        if (finalFeeCollateral != 0) {
            IHolding(tempData.holding).transfer({
                _token: _collateral,
                _to: _getManager().feeAddress(),
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
     * @notice If there is insufficient collateral for the `_jUsdAmount` specified by the liquidator, the function
     * calculates the maximum possible jUsd amount to repay based on the user's available collateral.
     *
     * @notice Requirements:
     * - `_user` must have holding.
     * - `_user` must be insolvent.
     * - `msg.sender` must have jUSD.
     * - `_jUsdAmount` must be <= user's borrowed amount
     *
     * @notice Effects:
     * - Retrieves collateral from specified strategies if needed.
     * - Adjusts the liquidator bonus and ensures it is less than the total required collateral.
     * - Repays user's debt in the amount of `jUsdAmountRepaid`.
     * - Removes used `collateralUsed` from `holding`.
     * - Sends liquidator their bonus.
     * - Sends fees to `feeAddress`.
     *
     * @notice Emits:
     * - `Liquidated` event indicating liquidation.
     *
     * @param _user address whose holding is to be liquidated.
     * @param _collateral token used for borrowing.
     * @param _jUsdAmount to repay.
     * @param _data  for strategies to retrieve collateral from in case the Holding balance is not enough.
     *
     * @return collateralUsed The amount of collateral used for liquidation.
     * @return jUsdAmountRepaid The amount of jUsd repaid.
     */
    function liquidate(
        address _user,
        address _collateral,
        uint256 _jUsdAmount,
        LiquidateCalldata calldata _data
    )
        external
        override
        nonReentrant
        whenNotPaused
        validAddress(_collateral)
        validAmount(_jUsdAmount)
        returns (uint256 collateralUsed, uint256 jUsdAmountRepaid)
    {
        // Initialize liquidation temporary data struct.
        LiquidateTempData memory tempData = LiquidateTempData({
            holdingManager: _getHoldingManager(),
            stablesManager: _getStablesManager(),
            holding: address(0),
            isRegistryActive: false,
            registryAddress: address(0),
            totalBorrowed: 0,
            totalAvailableCollateral: 0,
            totalRequiredCollateral: 0,
            totalFeeCollateral: 0,
            totalLiquidatorCollateral: 0,
            jUsdAmountToBurn: 0,
            exchangeRate: 0,
            collateralInStrategies: 0
        });

        // Get user's holding.
        tempData.holding = tempData.holdingManager.userHolding(_user);

        // Ensure that user has a holding account in the system.
        require(tempData.holdingManager.isHolding(tempData.holding), "3002");

        // Ensure collateral registry is active.
        (tempData.isRegistryActive, tempData.registryAddress) = tempData.stablesManager.shareRegistryInfo(_collateral);
        require(tempData.isRegistryActive, "1200");

        // Ensure liquidation amount <= borrowed.
        tempData.totalBorrowed = ISharesRegistry(tempData.registryAddress).borrowed(tempData.holding);
        tempData.jUsdAmountToBurn = _jUsdAmount;
        require(tempData.jUsdAmountToBurn <= tempData.totalBorrowed, "2003");

        // Ensure user is insolvent.
        require(!tempData.stablesManager.isSolvent({ _token: _collateral, _holding: tempData.holding }), "3073");

        // Calculate collateral required for the specified `_jUsdAmount`.
        tempData.exchangeRate = ISharesRegistry(tempData.registryAddress).getExchangeRate();
        tempData.totalRequiredCollateral = _getCollateralForJUsd({
            _collateral: _collateral,
            _jUsdAmount: tempData.jUsdAmountToBurn,
            _exchangeRate: tempData.exchangeRate
        });

        // Get user's total available collateral.
        tempData.totalAvailableCollateral = ISharesRegistry(tempData.registryAddress).collateral(tempData.holding);

        // Adjust total required collateral based on total available collateral.
        tempData.totalRequiredCollateral = tempData.totalRequiredCollateral > tempData.totalAvailableCollateral
            ? tempData.totalAvailableCollateral
            : tempData.totalRequiredCollateral;

        // Calculate and adjust liquidator's collateral if the liquidator is not the user.
        tempData.totalLiquidatorCollateral = _user == msg.sender
            ? 0
            : tempData.totalRequiredCollateral.mulDiv(liquidatorBonus, LIQUIDATION_PRECISION, Math.Rounding.Ceil);

        // Update total required collateral
        tempData.totalRequiredCollateral += tempData.totalLiquidatorCollateral;

        // If strategies are provided, retrieve collateral from strategies if needed.
        uint256 finalAvailableCollateralAmount = _data.strategies.length > 0
            ? _retrieveCollateral({
                _token: _collateral,
                _holding: tempData.holding,
                _amount: tempData.totalRequiredCollateral,
                _strategies: _data.strategies,
                _strategiesData: _data.strategiesData,
                useHoldingBalance: true
            })
            : tempData.totalRequiredCollateral - tempData.totalLiquidatorCollateral;

        // Re-calculate required collateral and liquidator bonus if obtained from strategies is less than required.
        if (tempData.totalRequiredCollateral >= finalAvailableCollateralAmount) {
            tempData.totalRequiredCollateral = finalAvailableCollateralAmount;
            // The formula to calculate Liquidator's Collateral (LC) is expressed as LC = FAC / (1 + (p/100)), where
            // LC represents the accurately recalculated totalLiquidatorCollateral.
            // To mitigate rounding errors, both 1 and liquidatorBonus are multiplied by 10.
            tempData.totalLiquidatorCollateral = _user != msg.sender
                ? (tempData.totalRequiredCollateral / (10 + liquidatorBonus.mulDiv(10, LIQUIDATION_PRECISION))) / 10
                : 0;
        }

        // Ensure liquidator's bonus is < totalRequiredCollateral.
        require(tempData.totalLiquidatorCollateral < tempData.totalRequiredCollateral, "3027");

        // Adjust collateral amount based on collateral token's decimals.
        uint256 collateralWithJUsdDecimals = tempData.totalRequiredCollateral;
        uint256 collateralDecimals = IERC20Metadata(_collateral).decimals();
        if (collateralDecimals > 18) {
            collateralWithJUsdDecimals = collateralWithJUsdDecimals / (10 ** (collateralDecimals - 18));
        } else if (collateralDecimals < 18) {
            collateralWithJUsdDecimals = collateralWithJUsdDecimals * 10 ** (18 - collateralDecimals);
        }

        // Convert collateral amount to USD equivalent based on current exchange rate.
        uint256 EXCHANGE_RATE_PRECISION = _getManager().EXCHANGE_RATE_PRECISION();
        tempData.jUsdAmountToBurn = collateralWithJUsdDecimals.mulDiv(tempData.exchangeRate, EXCHANGE_RATE_PRECISION)
            .mulDiv(EXCHANGE_RATE_PRECISION, _getManager().getJUsdExchangeRate());

        // Repay user's debt with jUsd owned by the liquidator.
        tempData.stablesManager.repay({
            _holding: tempData.holding,
            _token: _collateral,
            _amount: tempData.jUsdAmountToBurn,
            _burnFrom: msg.sender
        });

        // Remove collateral from holding.
        tempData.stablesManager.forceRemoveCollateral({
            _holding: tempData.holding,
            _token: _collateral,
            _amount: tempData.totalRequiredCollateral
        });

        // Send liquidator their bonus.
        if (tempData.totalLiquidatorCollateral > 0) {
            IHolding(tempData.holding).transfer({
                _token: _collateral,
                _to: msg.sender,
                _amount: tempData.totalLiquidatorCollateral
            });
        }

        // Send fees to fee address
        IHolding(tempData.holding).transfer({
            _token: _collateral,
            _to: _getManager().feeAddress(),
            _amount: tempData.totalRequiredCollateral - tempData.totalLiquidatorCollateral
        });

        // Emit event indicating liquidation.
        emit Liquidated({
            holding: tempData.holding,
            token: _collateral,
            amount: tempData.jUsdAmountToBurn,
            collateralUsed: tempData.totalRequiredCollateral
        });

        // Save the jUSD amount that has been repaid.
        jUsdAmountRepaid = tempData.jUsdAmountToBurn;
        // Save the amount of collateral that has been used to repay jUSD.
        collateralUsed = tempData.totalRequiredCollateral;
    }

    // -- Administration --

    /**
     * @notice Sets a new value for the liquidator bonus.
     * @dev The value must be less than LIQUIDATION_PRECISION.
     * @param _val The new value for the liquidator bonus.
     */
    function setLiquidatorBonus(uint256 _val) external override onlyAllowed {
        require(_val < LIQUIDATION_PRECISION, "2001");
        liquidatorBonus = _val;
    }

    /**
     * @notice Sets a new value for the self-liquidation fee.
     * @dev The value must be less than LIQUIDATION_PRECISION.
     * @param _val The new value for the self-liquidation fee.
     */
    function setSelfLiquidationFee(uint256 _val) external override onlyAllowed {
        require(_val < LIQUIDATION_PRECISION, "2001");
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
     * @param _collateral address of the collateral token.
     * @param _jUsdAmount amount of jUSD.
     * @param _exchangeRate collateral to jUSD.
     * @return totalCollateral The total amount of collateral required.
     */
    function _getCollateralForJUsd(
        address _collateral,
        uint256 _jUsdAmount,
        uint256 _exchangeRate
    ) private view returns (uint256 totalCollateral) {
        uint256 EXCHANGE_RATE_PRECISION = _getManager().EXCHANGE_RATE_PRECISION();
        // Calculate collateral amount based on its USD value.
        totalCollateral = _jUsdAmount.mulDiv(EXCHANGE_RATE_PRECISION, _exchangeRate, Math.Rounding.Ceil);
        // Adjust collateral amount in accordance with current jUSD price.
        totalCollateral =
            totalCollateral.mulDiv(_getManager().getJUsdExchangeRate(), EXCHANGE_RATE_PRECISION, Math.Rounding.Ceil);
        // Perform sanity check to avoid miscalculations.
        require(totalCollateral > 0, "3079");
        // Transform from 18 decimals to collateral's decimals
        uint256 collateralDecimals = IERC20Metadata(_collateral).decimals();
        if (collateralDecimals > 18) totalCollateral = totalCollateral * (10 ** (collateralDecimals - 18));
        else if (collateralDecimals < 18) totalCollateral = totalCollateral / (10 ** (18 - collateralDecimals));
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

            // Limit the withdrawal amount to ensure it does not exceed required amount.
            tempData.shares = tempData.shares >= _amount ? _amount : tempData.shares;

            // Withdraw collateral.
            (tempData.withdrawResult,) = IStrategyManager(_getManager().strategyManager()).claimInvestment(
                _holding, _strategies[i], tempData.shares, _token, _strategiesData[i]
            );

            // Ensure withdrawal went successful.
            require(tempData.withdrawResult > 0, string(abi.encodePacked("3015;", i)));

            // Update amount of retrieved collateral.
            tempData.retrievedCollateral += tempData.shares;

            // Emit event indicating collateral retrieval.
            emit CollateralRetrieved(_token, _holding, _strategies[i], tempData.shares);

            // Continue withdrawing from strategies only if the required amount has not been reached yet
            if (tempData.retrievedCollateral >= _amount) break;
            if (useHoldingBalance && IERC20(_token).balanceOf(_holding) >= _amount) break;
        }

        // Return the amount of retrieved collateral.
        return tempData.retrievedCollateral;
    }

    /**
     * @notice Utility function do get available Manager Contract.
     */
    function _getManager() private view returns (IManager) {
        return IManager(managerContainer.manager());
    }

    /**
     * @notice Utility function do get available StablesManager Contract.
     */
    function _getStablesManager() private view returns (IStablesManager) {
        return IStablesManager(_getManager().stablesManager());
    }

    /**
     * @notice Utility function do get available HoldingManager Contract.
     */
    function _getHoldingManager() private view returns (IHoldingManager) {
        return IHoldingManager(_getManager().holdingManager());
    }

    /**
     * @notice Utility function do get available SwapManager Contract.
     */
    function _getSwapManager() private view returns (ISwapManager) {
        return ISwapManager(_getManager().swapManager());
    }

    // -- Modifiers --

    /**
     * @notice Modifier to only allow access to a function by the contract manager.
     */
    modifier onlyAllowed() {
        require(msg.sender == address(_getManager()), "1000");
        _;
    }

    /**
     * @notice Modifier to ensure that the provided address is valid (not the zero address).
     * @param _address The address to validate
     */
    modifier validAddress(address _address) {
        require(_address != address(0), "3000");
        _;
    }

    /**
     * @notice Modifier to ensure that the provided amount is valid (greater than zero).
     * @param _amount The amount to validate
     */
    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "2001");
        _;
    }
}
