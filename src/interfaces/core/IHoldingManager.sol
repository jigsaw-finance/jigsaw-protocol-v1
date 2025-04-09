// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IManager } from "./IManager.sol";

/**
 * @title IHoldingManager
 * @notice Interface for the Holding Manager.
 */
interface IHoldingManager {
    // -- Custom types --

    /**
     * @notice Data used for multiple borrow.
     */
    struct BorrowData {
        address token;
        uint256 amount;
        uint256 minJUsdAmountOut;
    }

    /**
     * @notice Data used for multiple repay.
     */
    struct RepayData {
        address token;
        uint256 amount;
    }

    // -- Events --

    /**
     * @notice Emitted when a new Holding is created.
     * @param user The address of the user.
     * @param holdingAddress The address of the created holding.
     */
    event HoldingCreated(address indexed user, address indexed holdingAddress);

    /**
     * @notice Emitted when a deposit is made.
     * @param holding The address of the holding.
     * @param token The address of the token.
     * @param amount The amount deposited.
     */
    event Deposit(address indexed holding, address indexed token, uint256 amount);

    /**
     * @notice Emitted when a borrow action is performed.
     * @param holding The address of the holding.
     * @param token The address of the token.
     * @param jUsdMinted The amount of jUSD minted.
     * @param mintToUser Indicates if the amount is minted directly to the user.
     */
    event Borrowed(address indexed holding, address indexed token, uint256 jUsdMinted, bool mintToUser);

    /**
     * @notice Emitted when a borrow event happens using multiple collateral types.
     * @param holding The address of the holding.
     * @param length The number of borrow operations.
     * @param mintedToUser Indicates if the amounts are minted directly to the users.
     */
    event BorrowedMultiple(address indexed holding, uint256 length, bool mintedToUser);

    /**
     * @notice Emitted when a repay action is performed.
     * @param holding The address of the holding.
     * @param token The address of the token.
     * @param amount The amount repaid.
     * @param repayFromUser Indicates if the repayment is from the user's wallet.
     */
    event Repaid(address indexed holding, address indexed token, uint256 amount, bool repayFromUser);

    /**
     * @notice Emitted when a multiple repay operation happens.
     * @param holding The address of the holding.
     * @param length The number of repay operations.
     * @param repaidFromUser Indicates if the repayments are from the users' wallets.
     */
    event RepaidMultiple(address indexed holding, uint256 length, bool repaidFromUser);

    /**
     * @notice Emitted when the user wraps native coin.
     * @param user The address of the user.
     * @param amount The amount wrapped.
     */
    event NativeCoinWrapped(address user, uint256 amount);

    /**
     * @notice Emitted when the user unwraps into native coin.
     * @param user The address of the user.
     * @param amount The amount unwrapped.
     */
    event NativeCoinUnwrapped(address user, uint256 amount);

    /**
     * @notice Emitted when tokens are withdrawn from the holding.
     * @param holding The address of the holding.
     * @param token The address of the token.
     * @param totalAmount The total amount withdrawn.
     * @param feeAmount The fee amount.
     */
    event Withdrawal(address indexed holding, address indexed token, uint256 totalAmount, uint256 feeAmount);

    /**
     * @notice Emitted when the contract receives ETH.
     * @param from The address of the sender.
     * @param amount The amount received.
     */
    event Received(address indexed from, uint256 amount);

    // -- State variables --

    /**
     * @notice Returns the holding for a user.
     * @param _user The address of the user.
     * @return The address of the holding.
     */
    function userHolding(
        address _user
    ) external view returns (address);

    /**
     * @notice Returns the user for a holding.
     * @param holding The address of the holding.
     * @return The address of the user.
     */
    function holdingUser(
        address holding
    ) external view returns (address);

    /**
     * @notice Returns true if the holding was created.
     * @param _holding The address of the holding.
     * @return True if the holding was created, false otherwise.
     */
    function isHolding(
        address _holding
    ) external view returns (bool);

    /**
     * @notice Returns the address of the holding implementation to be cloned from.
     * @return The address of the current holding implementation.
     */
    function holdingImplementationReference() external view returns (address);

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     * @return The manager contract.
     */
    function manager() external view returns (IManager);

    /**
     * @notice Returns the address of the WETH contract to save on `manager.WETH()` calls.
     * @return The address of the WETH contract.
     */
    function WETH() external view returns (address);

    // -- User specific methods --

    /**
     * @notice Creates holding for the msg.sender.
     *
     * @notice Requirements:
     * - `msg.sender` must not have a holding within the protocol, as only one holding is allowed per address.
     * - Must be called from an EOA or whitelisted contract.
     *
     * @notice Effects:
     * - Clones `holdingImplementationReference`.
     * - Updates `userHolding` and `holdingUser` mappings with newly deployed `newHoldingAddress`.
     * - Initiates the `newHolding`.
     *
     * @notice Emits:
     * - `HoldingCreated` event indicating successful Holding creation.
     *
     * @return The address of the new holding.
     */
    function createHolding() external returns (address);

    /**
     * @notice Deposits a whitelisted token into the Holding.
     *
     * @notice Requirements:
     * - `_token` must be a whitelisted token.
     * - `_amount` must be greater than zero.
     * - `msg.sender` must have a valid holding.
     *
     * @param _token Token's address.
     * @param _amount Amount to deposit.
     */
    function deposit(address _token, uint256 _amount) external;

    /**
     * @notice Wraps native coin and deposits WETH into the holding.
     *
     * @dev This function must receive ETH in the transaction.
     *
     * @notice Requirements:
     *  - WETH must be whitelisted within protocol.
     * - `msg.sender` must have a valid holding.
     */
    function wrapAndDeposit() external payable;

    /**
     * @notice Withdraws a token from a Holding to a user.
     *
     * @notice Requirements:
     * - `_token` must be a valid address.
     * - `_amount` must be greater than zero.
     * - `msg.sender` must have a valid holding.
     *
     * @notice Effects:
     * - Withdraws the `_amount` of `_token` from the holding.
     * - Transfers the `_amount` of `_token` to `msg.sender`.
     * - Deducts any applicable fees.
     *
     * @param _token Token user wants to withdraw.
     * @param _amount Withdrawal amount.
     */
    function withdraw(address _token, uint256 _amount) external;

    /**
     * @notice Withdraws WETH from holding and unwraps it before sending it to the user.
     *
     * @notice Requirements:
     * - `_amount` must be greater than zero.
     * - `msg.sender` must have a valid holding.
     * - The low level native coin transfers must succeed.
     *
     * @notice Effects
     * - Transfers WETH from Holding address to address(this).
     * - Unwraps the WETH into native coin.
     * - Withdraws the `_amount` of WETH from the holding.
     * - Deducts any applicable fees.
     * - Transfers the unwrapped amount to `msg.sender`.
     *
     * @param _amount Withdrawal amount.
     */
    function withdrawAndUnwrap(
        uint256 _amount
    ) external;

    /**
     * @notice Borrows jUSD stablecoin to the user or to the holding contract.
     *
     * @dev The _amount does not account for the collateralization ratio and is meant to represent collateral's amount
     * equivalent to jUSD's value the user wants to receive.
     * @dev Ensure that the user will not become insolvent after borrowing before calling this function, as this
     * function will revert ("3009") if the supplied `_amount` does not adhere to the collateralization ratio set in
     * the registry for the specific collateral.
     *
     * @notice Requirements:
     * - `msg.sender` must have a valid holding.
     *
     * @notice Effects:
     * - Calls borrow function on `Stables Manager` Contract resulting in minting stablecoin based on the `_amount` of
     * `_token` collateral.
     *
     * @notice Emits:
     * - `Borrowed` event indicating successful borrow operation.
     *
     * @param _token Collateral token.
     * @param _amount The collateral amount equivalent for borrowed jUSD.
     * @param _mintDirectlyToUser If true, mints to user instead of holding.
     * @param _minJUsdAmountOut The minimum amount of jUSD that is expected to be received.
     *
     * @return jUsdMinted The amount of jUSD minted.
     */
    function borrow(
        address _token,
        uint256 _amount,
        uint256 _minJUsdAmountOut,
        bool _mintDirectlyToUser
    ) external returns (uint256 jUsdMinted);

    /**
     * @notice Borrows jUSD stablecoin to the user or to the holding contract using multiple collaterals.
     *
     * @dev This function will fail if any `amount` supplied in the `_data` does not adhere to the collateralization
     * ratio set in the registry for the specific collateral. For instance, if the collateralization ratio is 200%, the
     * maximum `_amount` that can be used to borrow is half of the user's free collateral, otherwise the user's holding
     * will become insolvent after borrowing.
     *
     * @notice Requirements:
     * - `msg.sender` must have a valid holding.
     * - `_data` must contain at least one entry.
     *
     * @notice Effects:
     * - Mints jUSD stablecoin for each entry in `_data` based on the collateral amounts.
     *
     * @notice Emits:
     * - `Borrowed` event for each entry indicating successful borrow operation.
     * - `BorrowedMultiple` event indicating successful multiple borrow operation.
     *
     * @param _data Struct containing data for each collateral type.
     * @param _mintDirectlyToUser If true, mints to user instead of holding.
     *
     * @return  The amount of jUSD minted for each collateral type.
     */
    function borrowMultiple(
        BorrowData[] calldata _data,
        bool _mintDirectlyToUser
    ) external returns (uint256[] memory);

    /**
     * @notice Repays jUSD stablecoin debt from the user's or to the holding's address and frees up the locked
     * collateral.
     *
     * @notice Requirements:
     * - `msg.sender` must have a valid holding.
     *
     * @notice Effects:
     * - Repays `_amount` jUSD stablecoin.
     *
     * @notice Emits:
     * - `Repaid` event indicating successful debt repayment operation.
     *
     * @param _token Collateral token.
     * @param _amount The repaid amount.
     * @param _repayFromUser If true, Stables Manager will burn jUSD from the msg.sender, otherwise user's holding.
     */
    function repay(address _token, uint256 _amount, bool _repayFromUser) external;

    /**
     * @notice Repays multiple jUSD stablecoin debts from the user's or to the holding's address and frees up the locked
     * collateral assets.
     *
     * @notice Requirements:
     * - `msg.sender` must have a valid holding.
     * - `_data` must contain at least one entry.
     *
     * @notice Effects:
     * - Repays stablecoin for each entry in `_data.
     *
     * @notice Emits:
     * - `Repaid` event indicating successful debt repayment operation.
     * - `RepaidMultiple` event indicating successful multiple repayment operation.
     *
     * @param _data Struct containing data for each collateral type.
     * @param _repayFromUser If true, it will burn from user's wallet, otherwise from user's holding.
     */
    function repayMultiple(RepayData[] calldata _data, bool _repayFromUser) external;

    // -- Administration --

    /**
     * @notice Triggers stopped state.
     */
    function pause() external;

    /**
     * @notice Returns to normal state.
     */
    function unpause() external;
}
