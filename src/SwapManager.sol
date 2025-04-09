// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IHolding } from "./interfaces/core/IHolding.sol";
import { IManager } from "./interfaces/core/IManager.sol";
import { IStablesManager } from "./interfaces/core/IStablesManager.sol";
import { ISwapManager } from "./interfaces/core/ISwapManager.sol";

/**
 * @title Swap Manager
 *
 * @notice This contract implements Uniswap's exact output multihop swap, for more information please refer to
 * https://docs.uniswap.org/contracts/v3/guides/swaps/multihop-swaps.
 *
 * @dev This contract inherits functionalities from `Ownable2Step`.
 *
 * @author Hovooo (@hovooo).
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract SwapManager is ISwapManager, Ownable2Step {
    using SafeERC20 for IERC20;

    /**
     * @notice Returns the address of the UniswapV3 Swap Router.
     */
    address public override swapRouter;

    /**
     * @notice Returns the address of the UniswapV3 Factory.
     */
    address public immutable override uniswapFactory;

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     */
    IManager public immutable override manager;

    /**
     * @notice Returns UniswapV3 pool initialization code hash used to deterministically compute the pool address.
     */
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /**
     * @notice Creates a new SwapManager contract.
     *
     * @param _initialOwner The initial owner of the contract.
     * @param _uniswapFactory the address of the UniswapV3 Factory.
     * @param _swapRouter the address of the UniswapV3 Swap Router.
     * @param _manager contract that contains all the necessary configs of the protocol.
     */
    constructor(
        address _initialOwner,
        address _uniswapFactory,
        address _swapRouter,
        address _manager
    ) Ownable(_initialOwner) {
        require(_uniswapFactory != address(0), "3000");
        require(_swapRouter != address(0), "3000");
        require(_manager != address(0), "3000");

        uniswapFactory = _uniswapFactory;
        swapRouter = _swapRouter;
        manager = IManager(_manager);
    }

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
    ) external override validPool(_swapPath, _amountOut) returns (uint256 amountIn) {
        // Ensure the caller is Liquidation Manager Contract.
        require(msg.sender == manager.liquidationManager(), "1000");

        // Initialize tempData struct.
        SwapTempData memory tempData = SwapTempData({
            tokenIn: _tokenIn,
            swapPath: _swapPath,
            userHolding: _userHolding,
            deadline: _deadline,
            amountOut: _amountOut,
            amountInMaximum: _amountInMaximum,
            router: swapRouter
        });

        // Transfer the specified `amountInMaximum` to this contract.
        IHolding(tempData.userHolding).transfer(tempData.tokenIn, address(this), tempData.amountInMaximum);

        // Approve the Router to spend `amountInMaximum` from address(this).
        IERC20(tempData.tokenIn).forceApprove({ spender: tempData.router, value: tempData.amountInMaximum });

        // The parameter path is encoded as (tokenOut, fee, tokenIn/tokenOut, fee, tokenIn).
        ISwapRouter.ExactOutputParams memory params = ISwapRouter.ExactOutputParams({
            path: tempData.swapPath,
            recipient: tempData.userHolding,
            deadline: tempData.deadline,
            amountOut: tempData.amountOut,
            amountInMaximum: tempData.amountInMaximum
        });

        // Execute the swap, returning the amountIn actually spent.
        try ISwapRouter(tempData.router).exactOutput(params) returns (uint256 _amountIn) {
            amountIn = _amountIn;
        } catch {
            revert("3084");
        }

        // Emit event indicating successful exact output swap.
        emit exactOutputSwap({
            holding: tempData.userHolding,
            path: tempData.swapPath,
            amountIn: amountIn,
            amountOut: tempData.amountOut
        });

        // If the swap did not require the full amountInMaximum to achieve the exact amountOut make a refund.
        if (amountIn < tempData.amountInMaximum) {
            // Decrease allowance of the router.
            IERC20(tempData.tokenIn).forceApprove({ spender: address(tempData.router), value: 0 });
            // Make the refund.
            IERC20(tempData.tokenIn).safeTransfer(tempData.userHolding, tempData.amountInMaximum - amountIn);
        }
    }

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
    ) external override onlyOwner validAddress(_swapRouter) {
        require(swapRouter != _swapRouter, "3017");
        emit SwapRouterUpdated(swapRouter, _swapRouter);
        swapRouter = _swapRouter;
    }

    /**
     * @notice Override to avoid losing contract ownership.
     */
    function renounceOwnership() public pure override {
        revert("1000");
    }

    // -- Private methods --

    /**
     * @notice Computes the pool address given the tokens of the pool and its fee.
     * @param tokenA The address of the first token of the UniswapV3 Pool.
     * @param tokenB The address of the second token of the UniswapV3 Pool.
     * @param fee The fee amount of the UniswapV3 Pool.
     */
    function _getPool(address tokenA, address tokenB, uint24 fee) private view returns (address) {
        // The address of the first token of the pool has to be smaller than the address of the second one.
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // Compute the pool address.
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff", uniswapFactory, keccak256(abi.encode(tokenA, tokenB, fee)), POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }

    // -- Modifiers --

    /**
     * @notice Validates that the address is not zero.
     * @param _address The address to validate.
     */
    modifier validAddress(
        address _address
    ) {
        require(_address != address(0), "3000");
        _;
    }

    /**
     * @notice Validates that jUSD UniswapV3 Pool is valid for the swap.
     *
     *   @notice Requirements:
     *  - `_path` must be of correct length.
     *  - jUSD UniswapV3 Pool specified in the `_path` has enough liquidity.
     */
    modifier validPool(bytes calldata _path, uint256 _amount) {
        // The shortest possible path is of 43 bytes, as an address takes 20 bytes and uint24 takes 3 bytes.
        require(_path.length >= 43, "3077");

        // Initialize tempData struct.
        ValidPoolTempData memory tempData = ValidPoolTempData({
            jUsd: IStablesManager(manager.stablesManager()).jUSD(),
            tokenA: address(bytes20(_path[0:20])),
            fee: uint24(bytes3(_path[20:23])),
            tokenB: address(bytes20(_path[23:43]))
        });

        // The first address in the path must be jUsd
        require(tempData.tokenA == address(tempData.jUsd), "3077");
        // There should be enough jUsd in the pool to perform self-liquidation.
        require(tempData.jUsd.balanceOf(_getPool(tempData.tokenA, tempData.tokenB, tempData.fee)) >= _amount, "3083");

        _;
    }
}
