// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IManager } from "./IManager.sol";

/**
 * @title IJigsawUSD
 * @dev Interface for the Jigsaw Stablecoin Contract.
 */
interface IJigsawUSD is IERC20 {
    /**
     * @notice event emitted when the mint limit is updated
     */
    event MintLimitUpdated(uint256 oldLimit, uint256 newLimit);

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     * @return The manager contract.
     */
    function manager() external view returns (IManager);

    /**
     * @notice Returns the max mint limit.
     */
    function mintLimit() external view returns (uint256);

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
