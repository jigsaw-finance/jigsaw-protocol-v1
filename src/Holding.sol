// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { OperationsLib } from "./libraries/OperationsLib.sol";

import { IHolding } from "./interfaces/core/IHolding.sol";

import { IHoldingManager } from "./interfaces/core/IHoldingManager.sol";
import { IManager } from "./interfaces/core/IManager.sol";
import { IStrategyManagerMin } from "./interfaces/core/IStrategyManagerMin.sol";
/**
 * @title Holding Contract
 *
 * @notice This contract is designed to manage the holding of tokens and allow operations like transferring tokens,
 * approving spenders, making generic calls, and minting Jigsaw Tokens. It is intended to be cloned and initialized to
 * ensure unique instances with specific managers.
 *
 * @dev This contract inherits functionalities from `ReentrancyGuard` and `Initializable`.
 *
 * @author Hovooo (@hovooo), Cosmin Grigore (@gcosmintech).
 *
 * @custom:security-contact support@jigsaw.finance
 */

contract Holding is IHolding, Initializable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @notice The address of the emergency invoker.
     */
    address public override emergencyInvoker;

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     */
    IManager public override manager;

    // --- Constructor ---

    /**
     * @dev To prevent the implementation contract from being used, the _disableInitializers function is invoked
     * in the constructor to automatically lock it when it is deployed.
     */
    constructor() {
        _disableInitializers();
    }

    // --- Initialization ---

    /**
     * @notice This function initializes the contract (instead of a constructor) to be cloned.
     *
     * @notice Requirements:
     * - The contract must not be already initialized.
     * - `_manager` must not be the zero address.
     *
     * @notice Effects:
     * - Sets `_initialized` to true.
     * - Sets `manager` to the provided `_manager` address.
     *
     * @param _manager Contract that holds all the necessary configs of the protocol.
     */
    function init(
        address _manager
    ) public initializer {
        require(_manager != address(0), "3065");
        manager = IManager(_manager);
    }

    // -- User specific methods --

    /**
     * @notice Sets the emergency invoker address for this holding.
     *
     * @notice Requirements:
     * - The caller must be the owner of this holding.
     *
     * @notice Effects:
     * - Updates the emergency invoker address to the provided value.
     * - Emits an event to track the change for off-chain monitoring.
     *
     * @param _emergencyInvoker The address to set as the emergency invoker.
     */
    function setEmergencyInvoker(
        address _emergencyInvoker
    ) external onlyUser {
        address oldInvoker = emergencyInvoker;
        emergencyInvoker = _emergencyInvoker;
        emit EmergencyInvokerSet(oldInvoker, _emergencyInvoker);
    }

    /**
     * @notice Approves an `_amount` of a specified token to be spent on behalf of the `msg.sender` by `_destination`.
     *
     * @notice Requirements:
     * - The caller must be allowed to make this call.
     *
     * @notice Effects:
     * - Safe approves the `_amount` of `_tokenAddress` to `_destination`.
     *
     * @param _tokenAddress Token user to be spent.
     * @param _destination Destination address of the approval.
     * @param _amount Withdrawal amount.
     */
    function approve(address _tokenAddress, address _destination, uint256 _amount) external override onlyAllowed {
        IERC20(_tokenAddress).forceApprove(_destination, _amount);
    }

    /**
     * @notice Transfers `_token` from the holding contract to `_to` address.
     *
     * @notice Requirements:
     * - The caller must be allowed.
     *
     * @notice Effects:
     * - Safe transfers `_amount` of `_token` to `_to`.
     *
     * @param _token Token address.
     * @param _to Address to move token to.
     * @param _amount Transfer amount.
     */
    function transfer(address _token, address _to, uint256 _amount) external override nonReentrant onlyAllowed {
        IERC20(_token).safeTransfer({ to: _to, value: _amount });
    }

    /**
     * @notice Executes generic call on the `contract`.
     *
     * @notice Requirements:
     * - The caller must be allowed.
     *
     * @notice Effects:
     * - Makes a low-level call to the `_contract` with the provided `_call` data.
     *
     * @param _contract The contract address for which the call will be invoked.
     * @param _call Abi.encodeWithSignature data for the call.
     *
     * @return success Indicates if the call was successful.
     * @return result The result returned by the call.
     */
    function genericCall(
        address _contract,
        bytes calldata _call
    ) external payable override nonReentrant onlyAllowed returns (bool success, bytes memory result) {
        (success, result) = _contract.call{ value: msg.value }(_call);
    }

    /**
     * @notice Executes an emergency generic call on the specified contract.
     *
     * @notice Requirements:
     * - The caller must be the designated emergency invoker.
     * - The emergency invoker must be an allowed invoker in the Manager contract.
     * - Protected by nonReentrant modifier to prevent reentrancy attacks.
     *
     * @notice Effects:
     * - Makes a low-level call to the `_contract` with the provided `_call` data.
     * - Forwards any ETH value sent with the transaction.
     *
     * @param _contract The contract address for which the call will be invoked.
     * @param _call Abi.encodeWithSignature data for the call.
     *
     * @return success Indicates if the call was successful.
     * @return result The result returned by the call.
     */
    function emergencyGenericCall(
        address _contract,
        bytes calldata _call
    ) external payable onlyEmergencyInvoker nonReentrant returns (bool success, bytes memory result) {
        (success, result) = _contract.call{ value: msg.value }(_call);
    }

    // -- Modifiers

    modifier onlyAllowed() {
        (,, bool isStrategyWhitelisted) = IStrategyManagerMin(manager.strategyManager()).strategyInfo(msg.sender);

        require(
            msg.sender == manager.holdingManager() || msg.sender == manager.liquidationManager()
                || msg.sender == manager.swapManager() || isStrategyWhitelisted,
            "1000"
        );
        _;
    }

    modifier onlyUser() {
        require(msg.sender == IHoldingManager(manager.holdingManager()).holdingUser(address(this)), "1000");
        _;
    }

    modifier onlyEmergencyInvoker() {
        require(msg.sender == emergencyInvoker && manager.allowedInvokers(msg.sender), "1000");
        _;
    }
}
