// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IReceiptToken } from "../core/IReceiptToken.sol";

/**
 * @title IStrategy
 * @notice Interface for a Strategies.
 *
 * @dev This interface defines the standard functions and events for a strategy contract.
 * @dev The strategy allows for the deposit, withdrawal, and reward claiming functionalities.
 * @dev It also provides views for essential information about the strategy's token and rewards.
 */
interface IStrategy {
    /**
     * @notice Emitted when funds are deposited.
     *
     * @param asset The address of the asset.
     * @param tokenIn The address of the input token.
     * @param assetAmount The amount of the asset.
     * @param tokenInAmount The amount of the input token.
     * @param shares The number of shares received.
     * @param recipient The address of the recipient.
     */
    event Deposit(
        address indexed asset,
        address indexed tokenIn,
        uint256 assetAmount,
        uint256 tokenInAmount,
        uint256 shares,
        address indexed recipient
    );

    /**
     * @notice Emitted when funds are withdrawn.
     *
     * @param asset The address of the asset.
     * @param recipient The address of the recipient.
     * @param shares The number of shares withdrawn.
     * @param amount The amount of the asset withdrawn.
     */
    event Withdraw(address indexed asset, address indexed recipient, uint256 shares, uint256 amount);

    /**
     * @notice Emitted when rewards are claimed.
     *
     * @param recipient The address of the recipient.
     * @param rewards The array of reward amounts.
     * @param rewardTokens The array of reward token addresses.
     */
    event Rewards(address indexed recipient, uint256[] rewards, address[] rewardTokens);

    /**
     * @notice Returns investments details.
     * @param _recipient The address of the recipient.
     * @return investedAmount The amount invested.
     * @return totalShares The total shares.
     */
    function recipients(
        address _recipient
    ) external view returns (uint256 investedAmount, uint256 totalShares);

    /**
     * @notice Returns the address of the token accepted by the strategy's underlying protocol as input.
     * @return tokenIn The address of the tokenIn.
     */
    function tokenIn() external view returns (address);

    /**
     * @notice Returns the address of token issued by the strategy's underlying protocol after deposit.
     * @return tokenOut The address of the tokenOut.
     */
    function tokenOut() external view returns (address);

    /**
     * @notice Returns the address of the strategy's main reward token.
     * @return rewardToken The address of the reward token.
     */
    function rewardToken() external view returns (address);

    /**
     * @notice Returns the address of the receipt token minted by the strategy itself.
     * @return receiptToken The address of the receipt token.
     */
    function receiptToken() external view returns (IReceiptToken);

    /**
     * @notice Returns the number of decimals of the strategy's shares.
     * @return sharesDecimals The number of decimals.
     */
    function sharesDecimals() external view returns (uint256);

    /**
     * @notice Returns the address of the receipt token.
     * @return receiptTokenAddress The address of the receipt token.
     */
    function getReceiptTokenAddress() external view returns (address receiptTokenAddress);

    /**
     * @notice Deposits funds into the strategy.
     *
     * @dev Some strategies won't give back any receipt tokens; in this case 'tokenOutAmount' will be 0.
     * 'tokenInAmount' will be equal to '_amount' in case the '_asset' is the same as strategy 'tokenIn()'.
     *
     * @param _asset The token to be invested.
     * @param _amount The token's amount.
     * @param _recipient The address of the recipient.
     * @param _data Extra data.
     *
     * @return tokenOutAmount The receipt tokens amount/obtained shares.
     * @return tokenInAmount The returned token in amount.
     */
    function deposit(
        address _asset,
        uint256 _amount,
        address _recipient,
        bytes calldata _data
    ) external returns (uint256 tokenOutAmount, uint256 tokenInAmount);

    /**
     * @notice Withdraws deposited funds.
     *
     * @dev Some strategies will allow only the tokenIn to be withdrawn. 'assetAmount' will be equal to 'tokenInAmount'
     * in case the '_asset' is the same as strategy 'tokenIn()'.
     *
     * @param _shares The amount to withdraw.
     * @param _recipient The address of the recipient.
     * @param _asset The token to be withdrawn.
     * @param _data Extra data.
     *
     * @return assetAmount The returned asset amount obtained from the operation.
     * @return tokenInAmount The returned token in amount.
     */
    function withdraw(
        uint256 _shares,
        address _recipient,
        address _asset,
        bytes calldata _data
    ) external returns (uint256 assetAmount, uint256 tokenInAmount);

    /**
     * @notice Claims rewards from the strategy.
     *
     * @param _recipient The address of the recipient.
     * @param _data Extra data.
     *
     * @return amounts The reward tokens amounts.
     * @return tokens The reward tokens addresses.
     */
    function claimRewards(
        address _recipient,
        bytes calldata _data
    ) external returns (uint256[] memory amounts, address[] memory tokens);

    /**
     * @notice Participants info.
     */
    struct RecipientInfo {
        uint256 investedAmount;
        uint256 totalShares;
    }
}
