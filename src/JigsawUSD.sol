// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import { IJigsawUSD } from "./interfaces/core/IJigsawUSD.sol";
import { IManager } from "./interfaces/core/IManager.sol";
import { IStablesManager } from "./interfaces/core/IStablesManager.sol";

/**
 * @title Jigsaw Stablecoin
 * @notice This contract implements a stablecoin named Jigsaw USD.
 *
 * @dev This contract inherits functionalities from `ERC20`, `Ownable2Step`, and `ERC20Permit`.
 *
 * It has additional features such as minting and burning, and specific roles for the owner and the Stables Manager.
 */
contract JigsawUSD is IJigsawUSD, ERC20, Ownable2Step, ERC20Permit {
    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     */
    IManager public immutable override manager;

    /**
     * @notice Returns the max mint limit.
     */
    uint256 public override mintLimit;

    /**
     * @notice Creates the JigsawUSD Contract.
     * @param _initialOwner The initial owner of the contract
     * @param _manager Contract that holds all the necessary configs of the protocol.
     */
    constructor(
        address _initialOwner,
        address _manager
    ) Ownable(_initialOwner) ERC20("Jigsaw USD", "jUSD") ERC20Permit("Jigsaw USD") {
        require(_manager != address(0), "3065");
        manager = IManager(_manager);
        mintLimit = 15e6 * (10 ** decimals()); // initial 15M limit
    }

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
    ) external override onlyOwner validAmount(_limit) {
        emit MintLimitUpdated(mintLimit, _limit);
        mintLimit = _limit;
    }

    // -- Write type methods --

    /**
     * @notice Mints tokens.
     *
     * @notice Requirements:
     * - Must be called by the Stables Manager Contract.
     *  .
     * @notice Effects:
     * - Mints the specified amount of tokens to the given address.
     *
     * @param _to Address of the user receiving minted tokens.
     * @param _amount The amount to be minted.
     */
    function mint(address _to, uint256 _amount) external override onlyStablesManager validAmount(_amount) {
        require(totalSupply() + _amount <= mintLimit, "2007");
        _mint(_to, _amount);
    }

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
    ) external override validAmount(_amount) {
        _burn(msg.sender, _amount);
    }

    /**
     * @notice Burns tokens from an address.
     *
     * @notice Requirements:
     * - Must be called by the Stables Manager Contract
     *
     * @notice Effects:
     *   - Burns the specified amount of tokens from the specified address.
     *
     * @param _user The user to burn it from.
     * @param _amount The amount of tokens to be burnt.
     */
    function burnFrom(address _user, uint256 _amount) external override validAmount(_amount) onlyStablesManager {
        _burn(_user, _amount);
    }

    // -- Modifiers --

    /**
     * @notice Ensures that the value is greater than 0.
     */
    modifier validAmount(
        uint256 _val
    ) {
        require(_val > 0, "2001");
        _;
    }

    /**
     * @notice Ensures that the caller is the Stables Manager
     */
    modifier onlyStablesManager() {
        require(msg.sender == manager.stablesManager(), "1000");
        _;
    }
}
