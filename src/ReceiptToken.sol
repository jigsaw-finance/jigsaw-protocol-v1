// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { IReceiptToken } from "./interfaces/core/IReceiptToken.sol";

/**
 * @title ReceiptToken
 * @dev Token minted when users invest into strategies based on Curve LP Token.
 *
 * @dev This contract inherits functionalities from `OwnableUpgradeable` and `ReentrancyGuardUpgradeable`.
 *
 * @author Hovooo (@hovooo).
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract ReceiptToken is IReceiptToken, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    address public minter;

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
     * - Sets the owner of the contract.
     * - The contract must not be already initialized.
     * - The `__minter` must not be the zero address.
     *
     * @notice Effects:
     * - Updates `_name`, `_symbol`, `minter` state variables.
     * - Stores `__owner` as owner.
     *
     * @param __name Receipt token name.
     * @param __symbol Receipt token symbol.
     * @param __minter Receipt token minter.
     * @param __owner Receipt token owner.
     */
    function initialize(
        string memory __name,
        string memory __symbol,
        address __minter,
        address __owner
    ) external override initializer {
        require(__minter != address(0), "3000");
        minter = __minter;

        // Initialize OwnableUpgradeable contract.
        __Ownable_init(__owner);
        // Initialize ERC20Upgradeable contract.
        __ERC20_init(__name, __symbol);
    }

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
    function mint(address _user, uint256 _amount) external override nonReentrant onlyMinterOrOwner {
        _mint(_user, _amount);
    }

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
    function burnFrom(address _user, uint256 _amount) external override nonReentrant onlyMinterOrOwner {
        _burn(_user, _amount);
    }

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
    ) external override nonReentrant onlyMinterOrOwner {
        require(_minter != minter, "3062");
        emit MinterUpdated({ oldMinter: minter, newMinter: _minter });
        minter = _minter;
    }

    /**
     * @dev Renounce ownership override to avoid losing contract's ownership.
     */
    function renounceOwnership() public pure override {
        revert("1000");
    }

    // -- Modifiers --

    modifier onlyMinterOrOwner() {
        require(msg.sender == minter || msg.sender == owner(), "1000");
        _;
    }
}
