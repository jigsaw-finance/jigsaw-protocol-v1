// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IManager } from "./IManager.sol";

/**
 * @title IHolding
 * @dev Interface for the Holding Contract.
 */
interface IHolding {
    // -- Events --

    /**
     * @notice Emitted when the emergency invoker is set.
     */
    event EmergencyInvokerSet(address indexed oldInvoker, address indexed newInvoker);

    // -- State variables --

    /**
     * @notice Returns the emergency invoker address.
     * @return The address of the emergency invoker.
     */
    function emergencyInvoker() external view returns (address);

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     */
    function manager() external view returns (IManager);

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
    ) external;

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
    function approve(address _tokenAddress, address _destination, uint256 _amount) external;

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
    function transfer(address _token, address _to, uint256 _amount) external;

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
    ) external payable returns (bool success, bytes memory result);

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
    ) external payable returns (bool success, bytes memory result);
}
