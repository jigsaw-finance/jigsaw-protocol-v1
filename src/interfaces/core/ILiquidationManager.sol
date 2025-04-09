// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IHoldingManager } from "./IHoldingManager.sol";
import { IManager } from "./IManager.sol";
import { IStablesManager } from "./IStablesManager.sol";
import { ISwapManager } from "./ISwapManager.sol";

/**
 * @title ILiquidationManager
 * @dev Interface for the LiquidationManager contract.
 */
interface ILiquidationManager {
    // -- Events --

    /**
     * @notice Emitted when self-liquidation occurs.
     * @param holding address involved in the self-liquidation.
     * @param token address of the collateral used for the self-liquidation.
     * @param amount of the `token` used for the self-liquidation.
     * @param collateralUsed amount used for the self-liquidation.
     */
    event SelfLiquidated(address indexed holding, address indexed token, uint256 amount, uint256 collateralUsed);

    /**
     * @notice Emitted when liquidation occurs.
     * @param holding address involved in the liquidation.
     * @param token address of the collateral used for the liquidation.
     * @param amount of the `token` used for the liquidation.
     * @param collateralUsed amount used for the liquidation.
     */
    event Liquidated(address indexed holding, address indexed token, uint256 amount, uint256 collateralUsed);

    /**
     * @notice Emitted when liquidation of bad debt occurs.
     * @param holding address involved in the liquidation of bad debt.
     * @param token address of the collateral used for the liquidation of bad debt.
     * @param amount of the `token` used for the liquidation of bad debt.
     * @param collateralUsed amount used for the liquidation of bad debt.
     */
    event BadDebtLiquidated(address indexed holding, address indexed token, uint256 amount, uint256 collateralUsed);

    /**
     * @notice Emitted when collateral is retrieved from a strategy.
     * @param token address retrieved as collateral.
     * @param holding address from which collateral is retrieved.
     * @param strategy address from which collateral is retrieved.
     * @param collateralRetrieved amount of collateral retrieved.
     */
    event CollateralRetrieved(
        address indexed token, address indexed holding, address indexed strategy, uint256 collateralRetrieved
    );

    /**
     * @notice Emitted when the self-liquidation fee is updated.
     * @param oldAmount The previous amount of the self-liquidation fee.
     * @param newAmount The new amount of the self-liquidation fee.
     */
    event SelfLiquidationFeeUpdated(uint256 oldAmount, uint256 newAmount);

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     * @return The manager contract.
     */
    function manager() external view returns (IManager);

    /**
     * @notice The max % amount the protocol gets when a self-liquidation operation happens.
     * @dev Uses 3 decimal precision, where 1% is represented as 1000.
     * @dev 8% is the default self-liquidation fee.
     */
    function selfLiquidationFee() external view returns (uint256);

    /**
     * @notice The max % amount the protocol gets when a self-liquidation operation happens.
     * @dev Uses 3 decimal precision, where 1% is represented as 1000.
     * @dev 10% is the max self-liquidation fee.
     */
    function MAX_SELF_LIQUIDATION_FEE() external view returns (uint256);

    /**
     * @notice returns utility variable used for preciser computations
     */
    function LIQUIDATION_PRECISION() external view returns (uint256);

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
     * @param _collateral address of the token used as collateral for borrowing
     * @param _jUsdAmount to repay
     * @param _swapParams used for the swap operation: swap path, maximum input amount, and slippage percentage
     * @param _strategiesParams data for strategies to retrieve collateral from
     *
     * @return collateralUsed for self-liquidation
     * @return jUsdAmountRepaid amount repaid
     */
    function selfLiquidate(
        address _collateral,
        uint256 _jUsdAmount,
        SwapParamsCalldata calldata _swapParams,
        StrategiesParamsCalldata calldata _strategiesParams
    ) external returns (uint256 collateralUsed, uint256 jUsdAmountRepaid);

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
    ) external returns (uint256 collateralUsed);

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
    function liquidateBadDebt(address _user, address _collateral, LiquidateCalldata calldata _data) external;

    // -- Administration --

    /**
     * @notice Sets a new value for the self-liquidation fee.
     * @dev The value must be less than MAX_SELF_LIQUIDATION_FEE.
     * @param _val The new value for the self-liquidation fee.
     */
    function setSelfLiquidationFee(
        uint256 _val
    ) external;

    /**
     * @notice Triggers stopped state.
     */
    function pause() external;

    /**
     * @notice Returns to normal state.
     */
    function unpause() external;

    // -- Structs --

    /**
     * @notice Temporary data structure used in the self-liquidation process.
     */
    struct SelfLiquidateTempData {
        IHoldingManager holdingManager; // Address of the Holding Manager contract
        IStablesManager stablesManager; // Address of the Stables Manager contract
        ISwapManager swapManager; // Address of the Swap Manager contract
        address holding; // Address of the user's Holding involved in self-liquidation
        bool isRegistryActive; // Flag indicating if the Registry is active
        address registryAddress; // Address of the Registry contract
        uint256 totalBorrowed; //  Total amount borrowed by user from the system
        uint256 totalAvailableCollateral; // Total available collateral in the Holding
        uint256 totalRequiredCollateral; // Total required collateral for self-liquidation
        uint256 totalSelfLiquidatableCollateral; // Total self-liquidatable collateral in the holding
        uint256 totalFeeCollateral; // Total fee collateral to be deducted
        uint256 jUsdAmountToBurn; // Amount of jUSD to burn during self-liquidation
        uint256 exchangeRate; // Current exchange rate.
        uint256 collateralInStrategies; // Total collateral locked in strategies
        bytes swapPath; // Path for token swapping
        uint256 deadline; // The latest time by which the swap operation must be completed.
        uint256 amountInMaximum; // Maximum amount to swap
        uint256 slippagePercentage; // Slippage percentage for token swapping
        bool useHoldingBalance; // Flag indicating whether to use Holding balance
        address[] strategies; // Array of strategy addresses
        bytes[] strategiesData; // Array of data associated with each strategy
    }

    /**
     * @notice Defines the necessary properties for self-liquidation for collateral swap.
     * @notice For optimal results, provide `_swapPath` and `_amountInMaximum` following the Uniswap Auto Router
     * guidelines. Refer to: https://blog.uniswap.org/auto-router.
     * @dev `_deadline` is a timestamp representing the latest time by which the swap operation must be completed.
     * @dev `slippagePercentage` represents the acceptable deviation percentage of `_amountInMaximum` from the
     * `totalSelfLiquidatableCollateral`.
     * @dev `slippagePercentage` is denominated in 5, where 100% is represented as 1e5.
     */
    struct SwapParamsCalldata {
        bytes swapPath;
        uint256 deadline;
        uint256 amountInMaximum;
        uint256 slippagePercentage;
    }

    /**
     * @notice Defines the necessary properties for self-liquidation using strategies, user has invested in.
     * @dev Set `useHoldingBalance` to true if user wishes to use holding's balance and strategies for self-liquidation.
     * `strategies` is an array of addresses of the strategies, in which the user has invested collateral in and wishes
     * to withdraw it from to perform a self-liquidation.
     * `strategiesData` is extra data used within each strategy to execute withdrawal
     */
    struct StrategiesParamsCalldata {
        bool useHoldingBalance;
        address[] strategies;
        bytes[] strategiesData;
    }

    /**
     * @notice Properties used for liquidation
     */
    struct LiquidateCalldata {
        address[] strategies;
        bytes[] strategiesData;
    }

    /**
     * @notice Properties used for collateral retrieval
     */
    struct CollateralRetrievalData {
        uint256 retrievedCollateral;
        uint256 shares;
        uint256 withdrawResult;
    }
}
