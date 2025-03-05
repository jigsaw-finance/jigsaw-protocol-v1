// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IManagerContainer } from "./IManagerContainer.sol";

/**
 * @title ISwapManager
 * @dev Interface for the SwapManager Contract.
 */
interface ISwapManager {
    // -- Events --

    /**
     * @notice Emitted when when the Swap Router is updated
     * @param oldAddress The old UniswapV3 Swap Router address.
     * @param newAddress The new UniswapV3 Swap Router address.
     */
    event SwapRouterUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Emitted when exact output swap is executed on UniswapV3 Pool.
     * @param holding The holding address associated with the user.
     * @param path The optimal path for the multi-hop swap.
     * @param amountIn The amount of the input token used for the swap.
     * @param amountOut The amount of the output token received after the swap.
     */
    event exactOutputSwap(address indexed holding, bytes path, uint256 amountIn, uint256 amountOut);

    /**
     * @notice Returns the address of the UniswapV3 Swap Router.
     */
    function swapRouter() external view returns (address);

    /**
     * @notice Returns the address of the UniswapV3 Factory.
     */
    function uniswapFactory() external view returns (address);

    /**
     * @notice Returns the contract that contains the address of the Manager contract.
     */
    function managerContainer() external view returns (IManagerContainer);

    // -- User specific methods --

    /**
     * @notice Swaps a minimum possible amount of `_tokenIn` for a fixed amount of `tokenOut` via `_swapPath`.
     *
     * @notice Requirements:
     * - The jUSD UniswapV3 Pool must be valid.
     * - The caller must be Liquidation Manager Contract.
     *
     * @notice Effects:
     * - Approves and transfers `tokenIn` from the `_userHolding`.
     * - Approves UniswapV3 Router to transfer `tokenIn` from address(this) to perform the `exactOutput` swap.
     * - Executes the `exactOutput` swap
     * - Handles any excess tokens.
     *
     * @param _tokenIn The address of the inbound asset.
     * @param _swapPath The optimal path for the multi-hop swap.
     * @param _userHolding The holding address associated with the user.
     * @param _deadline The timestamp representing the latest time by which the swap operation must be completed.
     * @param _amountOut The desired amount of `tokenOut`.
     * @param _amountInMaximum The maximum amount of `_tokenIn` to be swapped for the specified `_amountOut`.
     *
     * @return amountIn The amount of `_tokenIn` spent to receive the desired `amountOut` of `tokenOut`.
     */
    function swapExactOutputMultihop(
        address _tokenIn,
        bytes calldata _swapPath,
        address _userHolding,
        uint256 _deadline,
        uint256 _amountOut,
        uint256 _amountInMaximum
    ) external returns (uint256 amountIn);

    // -- Administration --

    /**
     * @notice Updates the Swap Router address.
     *
     * @notice Requirements:
     * - The new `_swapRouter` address must be valid and different from the current one.
     *
     * @notice Effects:
     * - Updates the `swapRouter` state variable.
     *
     * @notice Emits:
     * - `SwapRouterUpdated` event indicating successful swap router update operation.
     *
     * @param _swapRouter Swap Router's new address.
     */
    function setSwapRouter(
        address _swapRouter
    ) external;

    /**
     * @notice This struct stores temporary data required for a token swap
     */
    struct SwapTempData {
        address tokenIn; // The address of the token to be swapped
        bytes swapPath; // The swap path to be used for swap
        address userHolding; // User's holding address
        uint256 deadline; // The latest time by which the swap operation must be completed.
        uint256 amountOut; // The exact amount to be received after the swap
        uint256 amountInMaximum; // The maximum amount of `tokenIn` to be swapped
        address router; // The address of the UniswapV3 Swap Router to be used for the swap
    }

    /**
     * @notice This struct stores temporary data for the validPool modifier
     */
    struct ValidPoolTempData {
        IERC20 jUsd; // The interface the jUSD token
        address tokenA; // The address of the token A
        uint24 fee; // The fee for of the UniswapV3 Pool
        address tokenB; // The address of token B
    }
}
