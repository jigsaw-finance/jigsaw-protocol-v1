// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Receipt token interface
interface IReceiptToken is IERC20, IERC20Metadata, IERC20Errors {
    // -- Events --

    /**
     * @notice Emitted when the minter address is updated
     *  @param oldMinter The address of the old minter
     *  @param newMinter The address of the new minter
     */
    event MinterUpdated(address oldMinter, address newMinter);

    // --- Initialization ---

    /**
     * @notice This function initializes the contract (instead of a constructor) to be cloned.
     *
     * @notice Requirements:
     * - The contract must not be already initialized.
     * - The `__minter` must not be the zero address.
     *
     * @notice Effects:
     * - Sets `_initialized` to true.
     * - Updates `_name`, `_symbol`, `minter` state variables.
     * - Stores `__owner` as owner.
     *
     * @param __name Receipt token name.
     * @param __symbol Receipt token symbol.
     * @param __minter Receipt token minter.
     * @param __owner Receipt token owner.
     */
    function initialize(string memory __name, string memory __symbol, address __minter, address __owner) external;

    /**
     * @notice Mints receipt tokens.
     *
     * @notice Requirements:
     * - Must be called by the Minter or Owner of the Contract.
     *
     * @notice Effects:
     * - Mints the specified amount of tokens to the given address.
     *
     * @param _user Address of the user receiving minted tokens.
     * @param _amount The amount to be minted.
     */
    function mint(address _user, uint256 _amount) external;

    /**
     * @notice Burns tokens from an address.
     *
     * @notice Requirements:
     * - Must be called by the Minter or Owner of the Contract.
     *
     * @notice Effects:
     * - Burns the specified amount of tokens from the specified address.
     *
     * @param _user The user to burn it from.
     * @param _amount The amount of tokens to be burnt.
     */
    function burnFrom(address _user, uint256 _amount) external;

    /**
     * @notice Sets minter.
     *
     * @notice Requirements:
     * - Must be called by the Minter or Owner of the Contract.
     * - The `_minter` must be different from `minter`.
     *
     * @notice Effects:
     * - Updates minter state variable.
     *
     * @notice Emits:
     * - `MinterUpdated` event indicating minter update operation.
     *
     * @param _minter The user to burn it from.
     */
    function setMinter(
        address _minter
    ) external;
}
