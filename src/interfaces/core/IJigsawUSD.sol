// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IManager } from "./IManager.sol";

/**
 * @title IJigsawUSD
 * @dev Interface for the Jigsaw Stablecoin Contract.
 */
interface IJigsawUSD is IERC20 {
    // -- Events --

    /**
     * @notice event emitted when the mint limit is updated
     */
    event MintLimitUpdated(uint256 oldLimit, uint256 newLimit);

    /**
     * @notice Event emitted when a new manager is requested
     * @param newManager The address of the requested new manager
     */
    event NewManagerRequested(address newManager);

    /**
     * @notice Event emitted when the manager is updated
     * @param oldManager The address of the old manager
     * @param newManager The address of the new manager
     */
    event ManagerUpdated(address oldManager, address newManager);

    // -- State Variables --

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     * @return The manager contract.
     */
    function manager() external view returns (IManager);

    /**
     * @notice Returns the max mint limit.
     */
    function mintLimit() external view returns (uint256);

    // -- Owner specific methods --

    /**
     * @notice Sets the maximum mintable amount.
     *
     * @notice Requirements:
     * - Must be called by the contract owner.
     *
     * @notice Effects:
     * - Updates the `mintLimit` state variable.
     *
     * @notice Emits:
     * - `MintLimitUpdated` event indicating mint limit update operation.
     * @param _limit The new mint limit.
     */
    function updateMintLimit(
        uint256 _limit
    ) external;

    /**
     * @notice Registers manager change request.
     *
     * @notice Requirements:
     * - Contract must not be in active change.
     * - New manager must be different from current manager.
     * - New manager must not be the zero address.
     *
     * @notice Effects:
     * - Updates the `newManager` state variable.
     * - Updates the `newManagerTimestamp` state variable.
     *
     * @notice Emits:
     * - `NewManagerRequested` event indicating successful manager change request.
     *
     * @param _manager The address of the new Manager contract.
     */
    function requestNewManager(
        address _manager
    ) external;

    /**
     * @notice Updates the manager.
     *
     * @notice Requirements:
     * - Contract must be in active change.
     * - Timelock must expire.
     *
     * @notice Effects:
     * - Updates the `manager` state variable.
     * - Resets the `newManager` state variable.
     * - Resets the `newManagerTimestamp` state variable.
     *
     * @notice Emits:
     * - `ManagerUpdated` event indicating successful manager change.
     */
    function acceptManager() external;

    // -- Write type methods --

    /**
     * @notice Mints tokens.
     *
     * @notice Requirements:
     * - Must be called by the Stables Manager Contract
     *  .
     * @notice Effects:
     * - Mints the specified amount of tokens to the given address.
     *
     * @param _to Address of the user receiving minted tokens.
     * @param _amount The amount to be minted.
     */
    function mint(address _to, uint256 _amount) external;

    /**
     * @notice Burns tokens from the `msg.sender`.
     *
     * @notice Requirements:
     * - Must be called by the token holder.
     *
     * @notice Effects:
     * - Burns the specified amount of tokens from the caller's balance.
     *
     * @param _amount The amount of tokens to be burnt.
     */
    function burn(
        uint256 _amount
    ) external;

    /**
     * @notice Burns tokens from an address.
     *
     * - Must be called by the Stables Manager Contract
     *
     * @notice Effects: Burns the specified amount of tokens from the specified address.
     *
     * @param _user The user to burn it from.
     * @param _amount The amount of tokens to be burnt.
     */
    function burnFrom(address _user, uint256 _amount) external;
}
