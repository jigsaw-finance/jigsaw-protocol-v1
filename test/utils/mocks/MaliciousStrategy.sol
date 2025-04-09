// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IHolding } from "../../../src/interfaces/core/IHolding.sol";
import { IManager } from "../../../src/interfaces/core/IManager.sol";
import { IReceiptToken } from "../../../src/interfaces/core/IReceiptToken.sol";
import { IReceiptTokenFactory } from "../../../src/interfaces/core/IReceiptTokenFactory.sol";
import { IStrategy } from "../../../src/interfaces/core/IStrategy.sol";
import { StrategyBase } from "./StrategyBase.sol";

contract MaliciousStrategy is IStrategy, StrategyBase {
    using SafeERC20 for IERC20;

    address public immutable override tokenIn;
    address public immutable override tokenOut;
    address public override rewardToken;
    //returns the number of decimals of the strategy's shares
    uint256 public immutable override sharesDecimals;

    mapping(address => IStrategy.RecipientInfo) public override recipients;

    uint256 public totalInvestments;
    IReceiptToken public immutable override receiptToken;

    constructor(
        address _manager,
        address _token,
        string memory _receiptTokenName,
        string memory _receiptTokenSymbol
    ) StrategyBase(msg.sender) {
        manager = IManager(_manager);
        rewardToken = _token;
        tokenIn = _token;
        tokenOut = _token;
        sharesDecimals = IERC20Metadata(_token).decimals();
        receiptToken = IReceiptToken(
            IReceiptTokenFactory(manager.receiptTokenFactory()).createReceiptToken(
                _receiptTokenName, _receiptTokenSymbol, address(this), msg.sender
            )
        );
    }

    function deposit(
        address _asset,
        uint256 _amount,
        address _recipient,
        bytes calldata
    ) external override onlyValidAmount(_amount) onlyStrategyManager returns (uint256, uint256) {
        IHolding(_recipient).transfer(_asset, address(this), _amount);

        // solhint-disable-next-line reentrancy
        recipients[_recipient].investedAmount += _amount;
        // solhint-disable-next-line reentrancy
        recipients[_recipient].totalShares += _amount;
        // solhint-disable-next-line reentrancy
        totalInvestments += _amount;

        _mint(receiptToken, _recipient, _amount, IERC20Metadata(tokenIn).decimals());

        return (_amount, _amount);
    }

    function withdraw(
        uint256 _shares,
        address _recipient,
        address,
        bytes calldata
    ) external override onlyStrategyManager onlyValidAmount(_shares) returns (uint256, uint256, int256, uint256) {
        uint256 res = recipients[_recipient].totalShares;

        _burn(receiptToken, _recipient, res, recipients[_recipient].totalShares, IERC20Metadata(tokenOut).decimals());

        recipients[_recipient].totalShares = 0;
        recipients[_recipient].investedAmount = 0;
        totalInvestments = 0;
        return (0, res, 0, 0);
    }

    function claimRewards(
        address,
        bytes calldata
    ) external view override onlyStrategyManager returns (uint256[] memory, address[] memory) {
        revert("not implemented");
    }

    function getReceiptTokenAddress() external view override returns (address) {
        return address(receiptToken);
    }
}
