// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { OperationsLib } from "./libraries/OperationsLib.sol";

import { IHolding } from "./interfaces/core/IHolding.sol";
import { IManager } from "./interfaces/core/IManager.sol";
import { IManagerContainer } from "./interfaces/core/IManagerContainer.sol";
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
     * @notice Contract that contains the address of the manager contract.
     */
    IManagerContainer public override managerContainer;

    /**
     * @notice Indicates if the contract has been initialized.
     */
    bool private _initialized;

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
     * - `_managerContainer` must not be the zero address.
     *
     * @notice Effects:
     * - Sets `_initialized` to true.
     * - Sets `managerContainer` to the provided `_managerContainer` address.
     *
     * @param _managerContainer Contract that contains the address of the manager container contract.
     */
    function init(
        address _managerContainer
    ) public {
        require(!_initialized, "3072");
        require(_managerContainer != address(0), "3065");
        _initialized = true;
        managerContainer = IManagerContainer(_managerContainer);
    }

    // -- User specific methods --

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
        OperationsLib.safeApprove({ token: _tokenAddress, to: _destination, value: _amount });
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

    // -- Modifiers

    modifier onlyAllowed() {
        IManager manager = IManager(managerContainer.manager());
        (,, bool isStrategyWhitelisted) = IStrategyManagerMin(manager.strategyManager()).strategyInfo(msg.sender);

        require(
            msg.sender == manager.strategyManager() || msg.sender == manager.holdingManager()
                || msg.sender == manager.liquidationManager() || msg.sender == manager.swapManager()
                || isStrategyWhitelisted,
            "1000"
        );
        _;
    }
}
