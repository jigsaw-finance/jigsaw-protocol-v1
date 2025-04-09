// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IJigsawUSD } from "../core/IJigsawUSD.sol";
import { ISharesRegistry } from "../core/ISharesRegistry.sol";
import { IManager } from "./IManager.sol";

/**
 * @title IStablesManager
 * @notice Interface for the Stables Manager.
 */
interface IStablesManager {
    // -- Custom types --

    /**
     * @notice Structure to store state and deployment address for a share registry
     */
    struct ShareRegistryInfo {
        bool active; // Flag indicating if the registry is active
        address deployedAt; // Address where the registry is deployed
    }

    /**
     * @notice Temporary struct used to store data during borrow operations to avoid stack too deep errors.
     * @dev This struct helps organize variables used in the borrow function.
     * @param registry The shares registry contract for the collateral token
     * @param exchangeRatePrecision The precision used for exchange rate calculations
     * @param amount The normalized amount (18 decimals) of collateral being borrowed against
     * @param amountValue The USD value of the collateral amount
     */
    struct BorrowTempData {
        ISharesRegistry registry;
        uint256 exchangeRatePrecision;
        uint256 amount;
        uint256 amountValue;
    }

    // -- Events --

    /**
     * @notice Emitted when collateral is registered.
     * @param holding The address of the holding.
     * @param token The address of the token.
     * @param amount The amount of collateral.
     */
    event AddedCollateral(address indexed holding, address indexed token, uint256 amount);

    /**
     * @notice Emitted when collateral is unregistered.
     * @param holding The address of the holding.
     * @param token The address of the token.
     * @param amount The amount of collateral.
     */
    event RemovedCollateral(address indexed holding, address indexed token, uint256 amount);

    /**
     * @notice Emitted when a borrow action is performed.
     * @param holding The address of the holding.
     * @param jUsdMinted The amount of jUSD minted.
     * @param mintToUser Boolean indicating if the amount is minted directly to the user.
     */
    event Borrowed(address indexed holding, uint256 jUsdMinted, bool mintToUser);

    /**
     * @notice Emitted when a repay action is performed.
     * @param holding The address of the holding.
     * @param amount The amount repaid.
     * @param burnFrom The address to burn from.
     */
    event Repaid(address indexed holding, uint256 amount, address indexed burnFrom);

    /**
     * @notice Emitted when a registry is added.
     * @param token The address of the token.
     * @param registry The address of the registry.
     */
    event RegistryAdded(address indexed token, address indexed registry);

    /**
     * @notice Emitted when a registry is updated.
     * @param token The address of the token.
     * @param registry The address of the registry.
     */
    event RegistryUpdated(address indexed token, address indexed registry);

    /**
     * @notice Returns total borrowed jUSD amount using `token`.
     * @param _token The address of the token.
     * @return The total borrowed amount.
     */
    function totalBorrowed(
        address _token
    ) external view returns (uint256);

    /**
     * @notice Returns config info for each token.
     * @param _token The address of the token to get registry info for.
     * @return Boolean indicating if the registry is active and the address of the registry.
     */
    function shareRegistryInfo(
        address _token
    ) external view returns (bool, address);

    /**
     * @notice Returns protocol's stablecoin address.
     * @return The address of the Jigsaw stablecoin.
     */
    function jUSD() external view returns (IJigsawUSD);

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     * @return The manager contract.
     */
    function manager() external view returns (IManager);

    // -- User specific methods --

    /**
     * @notice Registers new collateral.
     *
     * @dev The amount will be transformed to shares.
     *
     * @notice Requirements:
     * - The caller must be allowed to perform this action directly. If user - use Holding Manager Contract.
     * - The `_token` must be whitelisted.
     * - The `_token`'s registry must be active.
     *
     * @notice Effects:
     * - Adds collateral for the holding.
     *
     * @notice Emits:
     * - `AddedCollateral` event indicating successful collateral addition operation.
     *
     * @param _holding The holding for which collateral is added.
     * @param _token Collateral token.
     * @param _amount Amount of tokens to be added as collateral.
     */
    function addCollateral(address _holding, address _token, uint256 _amount) external;

    /**
     * @notice Unregisters collateral.
     *
     * @notice Requirements:
     * - The contract must not be paused.
     * - The caller must be allowed to perform this action directly. If user - use Holding Manager Contract.
     * - The token's registry must be active.
     * - `_holding` must stay solvent after collateral removal.
     *
     * @notice Effects:
     * - Removes collateral for the holding.
     *
     * @notice Emits:
     * - `RemovedCollateral` event indicating successful collateral removal operation.
     *
     * @param _holding The holding for which collateral is removed.
     * @param _token Collateral token.
     * @param _amount Amount of collateral.
     */
    function removeCollateral(address _holding, address _token, uint256 _amount) external;

    /**
     * @notice Unregisters collateral.
     *
     * @notice Requirements:
     * - The caller must be the LiquidationManager.
     * - The token's registry must be active.
     *
     * @notice Effects:
     * - Force removes collateral from the `_holding` in case of liquidation, without checking if user is solvent after
     * collateral removal.
     *
     * @notice Emits:
     * - `RemovedCollateral` event indicating successful collateral removal operation.
     *
     * @param _holding The holding for which collateral is added.
     * @param _token Collateral token.
     * @param _amount Amount of collateral.
     */
    function forceRemoveCollateral(address _holding, address _token, uint256 _amount) external;

    /**
     * @notice Mints stablecoin to the user.
     *
     * @notice Requirements:
     * - The caller must be allowed to perform this action directly. If user - use Holding Manager Contract.
     * - The token's registry must be active.
     * - `_amount` must be greater than zero.
     *
     * @notice Effects:
     * - Mints stablecoin based on the collateral amount.
     * - Updates the total borrowed jUSD amount for `_token`, used for borrowing.
     * - Updates `_holdings`'s borrowed amount in `token`'s registry contract.
     * - Ensures the holding remains solvent.
     *
     * @notice Emits:
     * - `Borrowed`.
     *
     * @param _holding The holding for which collateral is added.
     * @param _token Collateral token.
     * @param _amount The collateral amount equivalent for borrowed jUSD.
     * @param _minJUsdAmountOut The minimum amount of jUSD that is expected to be received.
     * @param _mintDirectlyToUser If true, mints to user instead of holding.
     *
     * @return jUsdMintAmount The amount of jUSD minted.
     */
    function borrow(
        address _holding,
        address _token,
        uint256 _amount,
        uint256 _minJUsdAmountOut,
        bool _mintDirectlyToUser
    ) external returns (uint256 jUsdMintAmount);

    /**
     * @notice Repays debt.
     *
     * @notice Requirements:
     * - The caller must be allowed to perform this action directly. If user - use Holding Manager Contract.
     * - The token's registry must be active.
     * - The holding must have a positive borrowed amount.
     * - `_amount` must not exceed `holding`'s borrowed amount.
     * - `_amount` must be greater than zero.
     * - `_burnFrom` must not be the zero address.
     *
     * @notice Effects:
     * - Updates the total borrowed jUSD amount for `_token`, used for borrowing.
     * - Updates `_holdings`'s borrowed amount in `token`'s registry contract.
     * - Burns `_amount` jUSD tokens from `_burnFrom` address
     *
     * @notice Emits:
     * - `Repaid` event indicating successful repay operation.
     *
     * @param _holding The holding for which repay is performed.
     * @param _token Collateral token.
     * @param _amount The repaid jUSD amount.
     * @param _burnFrom The address to burn from.
     */
    function repay(address _holding, address _token, uint256 _amount, address _burnFrom) external;

    // -- Administration --

    /**
     * @notice Triggers stopped state.
     */
    function pause() external;

    /**
     * @notice Returns to normal state.
     */
    function unpause() external;

    // -- Getters --

    /**
     * @notice Returns true if user is solvent for the specified token.
     *
     * @dev The method reverts if block.timestamp - _maxTimeRange > exchangeRateUpdatedAt.
     *
     * @notice Requirements:
     * - `_holding` must not be the zero address.
     * - There must be registry for `_token`.
     *
     * @param _token The token for which the check is done.
     * @param _holding The user address.
     *
     * @return flag indicating whether `holding` is solvent.
     */
    function isSolvent(address _token, address _holding) external view returns (bool);

    /**
     * @notice Checks if a holding can be liquidated for a specific token.
     *
     * @notice Requirements:
     * - `_holding` must not be the zero address.
     * - There must be registry for `_token`.
     *
     * @param _token The token for which the check is done.
     * @param _holding The user address.
     *
     * @return flag indicating whether `holding` is liquidatable.
     */
    function isLiquidatable(address _token, address _holding) external view returns (bool);

    /**
     * @notice Computes the solvency ratio.
     *
     * @dev Solvency ratio is calculated based on the used collateral type, its collateralization and exchange rates,
     * and `_holding`'s borrowed amount.
     *
     * @param _holding The holding address to check for.
     * @param registry The Shares Registry Contract for the token.
     * @param rate The rate to compute ratio for (either collateralization rate for `isSolvent` or liquidation
     * threshold for `isLiquidatable`).
     *
     * @return The calculated solvency ratio.
     */
    function getRatio(address _holding, ISharesRegistry registry, uint256 rate) external view returns (uint256);
}
